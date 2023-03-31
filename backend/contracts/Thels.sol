// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract Thels is Ownable {
    using CFAv1Library for CFAv1Library.InitData;

    struct Token {
        address tokenAddress;
        AggregatorV3Interface priceFeed; // Chainlink price feed
        uint256 borrowPercent; // 100 => 10.0%
    }

    struct Stream {
        address receiver;
        int96 flowRate;
        uint256 start;
        uint256 end;
        uint256 fee;
        uint256 buffer;
    }

    event AddedCollateral(
        address indexed borrower,
        address token,
        uint256 amount
    );
    event RemovedCollateral(
        address indexed borrower,
        address token,
        uint256 amount
    );
    event RepaidDebt(address indexed borrower, uint256 amount);
    event StartedStream(
        address indexed borrower,
        address receiver,
        Stream stream
    );
    event StoppedStream(
        address indexed borrower,
        address receiver,
        Stream stream
    );
    event AddedUSDC(address indexed lender, uint256 amount);
    event RemovedUSDC(address indexed lender, uint256 amount);
    event Liquidated(address indexed borrower, uint256 amount);

    uint256 public constant FEE = 50; // 50 => 5.0%
    uint256 public constant BUFFER = 20; // 20 => 2.0%

    mapping(address => mapping(address => uint256)) public depositAmounts; // tokens and deposit amounts of each user
    mapping(address => mapping(address => Stream)) public streams; // opened streams of each user
    mapping(address => uint256) public lendAmounts; // USDC lend amount of each user
    mapping(address => uint256) public borrowAmounts; // USDC borrow amount of each user
    mapping(address => Token) public allowedTokens; // mapping that shows if a token can be used as collateral
    address[] public deposited; // users who have made a deposit
    address[] public allowedTokenList; // list of tokens that can be used as collateral
    IERC20 public USDCToken;
    ISuperToken public USDCxToken;
    CFAv1Library.InitData public cfaV1;
    ISwapRouter public router;

    constructor(
        address _USDCToken,
        address _USDCxToken,
        address _SuperfluidHost,
        address _UniswapRouter
    ) {
        USDCToken = IERC20(_USDCToken);
        USDCxToken = ISuperToken(_USDCxToken);
        ISuperfluid _host = ISuperfluid(_SuperfluidHost);
        router = ISwapRouter(_UniswapRouter);
        // initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            _host,
            // here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(
                    _host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );

        // approve tokens for Superfluid contract
        USDCToken.approve(_USDCxToken, type(uint256).max);
    }

    // deposit an allowed token
    function deposit(address token, uint256 amount) public {
        require(
            allowedTokens[token].tokenAddress != address(0),
            "Token is not allowed as collateral."
        );
        IERC20 _token = IERC20(token);
        _token.transferFrom(msg.sender, address(this), amount);
        depositAmounts[msg.sender][token] += amount;
        emit AddedCollateral(msg.sender, token, amount);
    }

    // withdraw deposited token
    function withdraw(address token, uint256 amount) public {
        require(
            allowedTokens[token].tokenAddress != address(0),
            "Token is not allowed as collateral."
        );
        require(
            depositAmounts[msg.sender][token] >= amount,
            "Not enough balance."
        );
        require(
            getBorrowableAmount(msg.sender) >=
                (((getTokenPrice(allowedTokens[token]) * amount) / (10**21)) *
                    allowedTokens[token].borrowPercent +
                    borrowAmounts[msg.sender]),
            "Cannot withdraw without paying debt."
        );
        IERC20 _token = IERC20(token);
        depositAmounts[msg.sender][token] -= amount;
        _token.transfer(msg.sender, amount);
        emit RemovedCollateral(msg.sender, token, amount);
    }

    // repay debt
    function repay(uint256 amount) public {
        require(
            amount <= borrowAmounts[msg.sender],
            "Cannot repay more than owed."
        );
        USDCToken.transferFrom(msg.sender, address(this), amount);
        USDCxToken.upgrade(amount);
        borrowAmounts[msg.sender] -= amount;
        emit RepaidDebt(msg.sender, amount);
    }

    // start a stream to an address
    // receiver: receiving address
    // flowRate: amount of wei / second
    // endTime: unix timestamp of ending time
    function startStream(
        address receiver,
        int96 flowRate,
        uint256 endTime
    ) public {
        require(endTime > block.timestamp, "Cannot set end time to past.");
        Stream storage stream = streams[msg.sender][receiver];
        require(stream.start == 0, "Stream already exists.");
        uint256 totalBorrow = uint256(flowRate) * (endTime - block.timestamp);
        uint256 fee = (totalBorrow * FEE) / 1000;
        uint256 buffer = (totalBorrow * BUFFER) / 1000;
        require(
            totalBorrow + fee + buffer < getBorrowableAmount(msg.sender),
            "Cannot borrow more than allowed."
        );
        borrowAmounts[msg.sender] += totalBorrow + fee + buffer;
        addStream(
            stream,
            receiver,
            flowRate,
            block.timestamp,
            endTime,
            fee,
            buffer
        );
        cfaV1.createFlow(receiver, USDCxToken, flowRate);
        emit StartedStream(msg.sender, receiver, stream);
    }

    // stop a previously opened stream and distribute fee rewards,
    // also refund buffer if closed before expiring.
    function stopStream(address receiver) public {
        Stream storage stream = streams[msg.sender][receiver];
        require(stream.start != 0, "Stream does not exist.");
        cfaV1.deleteFlow(address(this), receiver, USDCxToken);
        uint256 extraDebt = getRemainingAmount(stream);
        if (!hasElapsed(stream)) {
            extraDebt += stream.buffer;
        }
        if (extraDebt > 0) {
            // will be reduced from debt, if debt is paid,
            // it is added to lent amount instead
            if (borrowAmounts[msg.sender] < extraDebt) {
                lendAmounts[msg.sender] +=
                    extraDebt -
                    borrowAmounts[msg.sender];
                borrowAmounts[msg.sender] = 0;
            } else {
                borrowAmounts[msg.sender] -= extraDebt;
            }
        }
        distributeRewards(stream.fee);
        emit StoppedStream(msg.sender, receiver, stream);
        delete streams[msg.sender][receiver];
    }

    // lend USDC
    function convertToUSDCx(uint256 amount) public {
        USDCToken.transferFrom(msg.sender, address(this), amount);
        USDCxToken.upgrade(amount);
        if (lendAmounts[msg.sender] == 0) {
            deposited.push(msg.sender);
        }
        lendAmounts[msg.sender] += amount;
        emit AddedUSDC(msg.sender, amount);
    }

    // withdraw USDC
    function convertToUSDC(uint256 amount) public {
        require(
            amount <= lendAmounts[msg.sender],
            "Cannot withdraw more than supplied."
        );
        lendAmounts[msg.sender] -= amount;
        USDCxToken.downgrade(amount);
        USDCToken.transfer(msg.sender, amount);
        emit RemovedUSDC(msg.sender, amount);
    }

    // liquidate borrower's token if the price of it drops below the borrowing amount
    function liquidate(address user) public {
        require(
            getBorrowableAmount(user) < borrowAmounts[user],
            "Colatteral is larger than debt."
        );

        uint256 amount = 0;
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams(
                    allowedTokenList[i],
                    address(USDCToken),
                    3000,
                    address(this),
                    block.timestamp + 600,
                    depositAmounts[user][allowedTokenList[i]],
                    0,
                    0
                );
            depositAmounts[user][allowedTokenList[i]] = 0;
            amount += router.exactInputSingle(params);
        }
        uint256 rewardAmount = (amount * FEE) / 1000;
        USDCToken.transfer(msg.sender, rewardAmount);
        USDCxToken.upgrade(amount - rewardAmount);
        lendAmounts[address(this)] += amount - rewardAmount;
        emit Liquidated(user, amount);
    }

    // stop stream if the stream has past the end time
    function stopFinishedStream(address sender, address receiver) public {
        Stream storage stream = streams[sender][receiver];
        require(stream.end < block.timestamp, "Stream has not finished.");
        cfaV1.deleteFlow(address(this), receiver, USDCxToken);
        uint256 rewardAmount = (stream.buffer * FEE) / 1000;
        USDCxToken.downgrade(rewardAmount);
        USDCToken.transfer(msg.sender, rewardAmount);
        lendAmounts[address(this)] += stream.buffer - rewardAmount;
        distributeRewards(stream.fee);
        emit StoppedStream(sender, receiver, stream);
        delete streams[sender][receiver];
    }

    // gets the total collateral value of a user
    function getCollateralValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            uint256 currentTokenAmount = depositAmounts[user][
                allowedTokenList[i]
            ];
            if (currentTokenAmount > 0) {
                totalValue +=
                    (currentTokenAmount *
                        getTokenPrice(allowedTokens[allowedTokenList[i]])) /
                    10**18;
            }
        }
        return totalValue;
    }

    // get the total borrowable amount of a user
    function getBorrowableAmount(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            uint256 currentTokenAmount = depositAmounts[user][
                allowedTokenList[i]
            ];
            if (currentTokenAmount > 0) {
                totalValue +=
                    (currentTokenAmount *
                        getTokenPrice(allowedTokens[allowedTokenList[i]]) *
                        allowedTokens[allowedTokenList[i]].borrowPercent) /
                    10**21;
            }
        }
        if (totalValue < borrowAmounts[user]) {
            return 0;
        }
        return totalValue - borrowAmounts[user];
    }

    function getTotalUSDCx() public view returns (uint256) {
        return USDCxToken.balanceOf(address(this));
    }

    // allow token as collateral: admin function
    function allowToken(
        address tokenAddress,
        address priceFeedAddress,
        uint256 borrowPercent
    ) public onlyOwner {
        require(
            allowedTokens[tokenAddress].tokenAddress == address(0),
            "Token is already allowed."
        );
        allowedTokens[tokenAddress] = Token(
            tokenAddress,
            AggregatorV3Interface(priceFeedAddress),
            borrowPercent
        );
        allowedTokenList.push(tokenAddress);
    }

    // remove token from being a collateral: admin function
    // TODO: repay all deposited tokens
    function revokeToken(address tokenAddress) public onlyOwner {
        require(
            allowedTokens[tokenAddress].tokenAddress != address(0),
            "Token is not allowed."
        );
        delete allowedTokens[tokenAddress];

        // remove token from array
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            if (allowedTokenList[i] == tokenAddress) {
                allowedTokenList[i] = allowedTokenList[
                    allowedTokenList.length - 1
                ];
                allowedTokenList.pop();
                return;
            }
        }
    }

    // withdraw protocol fees: admin function
    function withdrawFees(uint256 amount) public onlyOwner {
        require(
            amount <= lendAmounts[address(this)],
            "Cannot withdraw more than earned."
        );
        USDCxToken.downgrade(amount);
        USDCToken.transfer(msg.sender, amount);
        lendAmounts[address(this)] -= amount;
    }

    // distributes amount of fee to lenders
    function distributeRewards(uint256 amount) private {
        uint256 totalLendAmount = 0;
        for (uint256 i = 0; i < deposited.length; i++) {
            totalLendAmount += lendAmounts[deposited[i]];
        }

        for (uint256 i = 0; i < deposited.length; i++) {
            lendAmounts[deposited[i]] +=
                (amount * lendAmounts[deposited[i]]) /
                totalLendAmount;
        }
    }

    // add stream info to streams struct
    function addStream(
        Stream storage stream,
        address receiver,
        int96 flowRate,
        uint256 start,
        uint256 end,
        uint256 fee,
        uint256 buffer
    ) private {
        stream.receiver = receiver;
        stream.flowRate = flowRate;
        stream.start = start;
        stream.end = end;
        stream.fee = fee;
        stream.buffer = buffer;
    }

    // returns the price in wei (10^18)
    function getTokenPrice(Token memory token) private view returns (uint256) {
        (, int256 price, , , ) = token.priceFeed.latestRoundData();
        return uint256(price) * 10**(18 - token.priceFeed.decimals());
    }

    // gets the remaining time for a stream in seconds
    function getRemainingAmount(Stream memory stream)
        private
        view
        returns (uint256)
    {
        if (stream.end < block.timestamp) {
            return 0;
        }
        return (stream.end - block.timestamp) * uint256(stream.flowRate);
    }

    // returns true if stream has elapsed
    function hasElapsed(Stream memory stream) private view returns (bool) {
        return (block.timestamp < stream.end);
    }

    // gets the total amount of stream in seconds
    function getTotalAmount(Stream memory stream)
        private
        pure
        returns (uint256)
    {
        return (stream.end - stream.start) * uint256(stream.flowRate);
    }

    // adds fee to an amount
    function addFee(uint256 amount, uint256 fee)
        private
        pure
        returns (uint256)
    {
        return (amount * ((1000 + fee) / 1000));
    }
}
