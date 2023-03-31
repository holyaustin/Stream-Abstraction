// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {ISuperfluid, ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ThelsStream is Ownable {
    using CFAv1Library for CFAv1Library.InitData;
    using SafeMath for uint256;

    uint256 public _minPenalty = 1000 * (10**18); // for STABLES 1000 USD
    uint256 public _minStreamTime = 604800; // 7 DAYS in SECs

    struct Stream {
        int96 flowRate;
        uint256 start;
        uint256 end;
        uint256 bufferAmount;
        uint256 claimPenaltyAvailable;
        uint256 penaltyAmount;
    }

    // superToken => sender => recipient => Stream
    mapping(address => mapping(address => mapping(address => Stream)))
        public streams;
    // avalaible Superfluid tokens
    mapping(address => mapping(address => uint256))
        public availableSFTokenBalances;
    // avalaible ERC20 tokens
    mapping(address => mapping(address => uint256)) public erc20TokenBalances;

    event Erc20Deposited(address erc20token, address from, uint256 amount);
    event TokenAllowed(address erc20token);
    event StreamInitiated(
        address superToken,
        address sender,
        address receiver,
        int96 flowRate
    );
    event StreamCanceled(address superToken, address sender, address receiver);

    //initialize cfaV1 variable
    CFAv1Library.InitData public cfaV1;

    constructor(ISuperfluid host) {
        //initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );
    }

    // deposit ERC20 token to the contract
    function depositErc20(address _token, uint256 _amount)
        public
        returns (bool)
    {
        require(_amount > 0, "Amount must be higher than zero!");
        erc20TokenBalances[_token][msg.sender] = erc20TokenBalances[_token][
            msg.sender
        ].add(_amount);
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        emit Erc20Deposited(_token, msg.sender, _amount);
        return true;
    }

    // withdraw ERC20 token from the contract
    function withdrawErc20(
        address _recipient,
        address _token,
        uint256 _amount
    ) public returns (bool) {
        require(
            erc20TokenBalances[_token][msg.sender].sub(_amount) >= 0,
            "Not enough tokens to withdraw"
        );
        erc20TokenBalances[_token][_recipient] = erc20TokenBalances[_token][
            _recipient
        ].sub(_amount);
        IERC20(_token).transfer(_recipient, _amount);
        return true;
    }

    // get ERC 20 token balance of the owner
    function getErc20TokenBalance(address _tokenOwner, address _token)
        public
        view
        returns (uint256)
    {
        return erc20TokenBalances[_token][_tokenOwner];
    }

    // get superfluid token balance of the owner
    function getSFTokenBalance(address _tokenOwner, address _superfluidToken)
        public
        view
        returns (uint256)
    {
        // return ISuperToken(_superfluidToken).balanceOf(_tokenOwner); // wont work as a sender is this contract
        return availableSFTokenBalances[_superfluidToken][_tokenOwner];
    }

    // get info of stream
    function getStream(
        address _superToken,
        address _sender,
        address _recipient
    ) public view returns (Stream memory) {
        return streams[_superToken][_sender][_recipient];
    }

    // upgrade erc20 token to superfluid token
    function upgradeToken(
        address _token,
        address _superToken,
        uint256 _amount
    ) public returns (bool) {
        require(
            erc20TokenBalances[_token][msg.sender].sub(_amount) >= 0,
            "Not enough tokens to upgrade"
        );
        // update balances
        erc20TokenBalances[_token][msg.sender] = erc20TokenBalances[_token][
            msg.sender
        ].sub(_amount);
        availableSFTokenBalances[_superToken][
            msg.sender
        ] = availableSFTokenBalances[_superToken][msg.sender].add(_amount);
        // alow to upgrade erc20 tokens
        IERC20(_token).approve(_superToken, _amount);
        // upgrade erc20 token to Superfluid token
        ISuperToken(_superToken).upgrade(_amount);
    }

    // downgrade superfluid token to erc20 token
    function downgradeToken(
        address _token,
        address _superToken,
        uint256 _amount
    ) public returns (bool) {
        require(
            availableSFTokenBalances[_superToken][msg.sender].sub(_amount) >= 0,
            "Not enough Superfluid Tokens to downgrade"
        );
        // update balances
        erc20TokenBalances[_token][msg.sender] = erc20TokenBalances[_token][
            msg.sender
        ].add(_amount);
        availableSFTokenBalances[_superToken][
            msg.sender
        ] = availableSFTokenBalances[_superToken][msg.sender].sub(_amount);
        ISuperToken(_superToken).downgrade(_amount);
    }

    // init stream
    function startStream(
        address _receiver,
        address _superToken,
        int96 _flowRate, // in wei/second
        uint256 _bufferTime, // in seconds
        uint256 _streamingPeriod // in seconds
    ) public {
        require(
            (availableSFTokenBalances[_superToken][msg.sender] -
                calculateStreamAmount(_flowRate, _streamingPeriod) -
                calculateBuffer(_flowRate, _bufferTime) -
                calculatePenalty(_flowRate)) > 0,
            "Not enough Supertokens to stream"
        );
        require(
            streams[_superToken][msg.sender][_receiver].flowRate == 0,
            "You have been already streaming to this account, you need to cancel stream first."
        );

        ISuperfluidToken superToken = ISuperfluidToken(_superToken);
        // update superfluid token balance of the sender
        uint256 _streamAmount = calculateStreamAmount(
            _flowRate,
            _streamingPeriod
        );
        uint256 _bufferAmount = calculateBuffer(_flowRate, _bufferTime);
        uint256 _penaltyAmount = calculatePenalty(_flowRate);
        uint256 reservedTokens = _streamAmount + _bufferAmount + _penaltyAmount;

        // update balance
        availableSFTokenBalances[_superToken][
            msg.sender
        ] = availableSFTokenBalances[_superToken][msg.sender].sub(
            reservedTokens
        );

        // set the stream into mapping
        uint256 _end = (block.timestamp).add(_streamingPeriod);
        uint256 _claimPenaltyAvailable = _end.add(_bufferTime);
        addStream(
            _superToken,
            msg.sender,
            _receiver,
            _flowRate,
            block.timestamp,
            _end,
            _bufferAmount,
            _claimPenaltyAvailable,
            _penaltyAmount
        );

        // start stream
        cfaV1.createFlow(_receiver, superToken, _flowRate);
        emit StreamInitiated(_superToken, msg.sender, _receiver, _flowRate);
    }

    // add stream info to streams struct
    function addStream(
        address _superToken,
        address _sender,
        address _receiver,
        int96 _flowrate,
        uint256 _start,
        uint256 _end,
        uint256 _bufferAmount,
        uint256 _claimPenaltyAvailable,
        uint256 _penaltyAmount
    ) internal {
        Stream storage s = streams[_superToken][_sender][_receiver];
        s.flowRate = _flowrate;
        s.start = _start;
        s.end = _end;
        s.bufferAmount = _bufferAmount;
        s.claimPenaltyAvailable = _claimPenaltyAvailable;
        s.penaltyAmount = _penaltyAmount;
    }

    function calculateStreamAmount(int96 _flowRate, uint256 _streamingPeriod)
        public
        view
        returns (uint256)
    {
        return (uint256(_flowRate) * _streamingPeriod);
    }

    function calculateBuffer(int96 _flowrate, uint256 _bufferTime)
        public
        view
        returns (uint256)
    {
        uint256 buffer;
        buffer = uint256(_flowrate) * _bufferTime;
        return buffer;
    }

    function calculatePenalty(int96 _flowrate) public view returns (uint256) {
        uint256 calculatedPenalty = uint256(_flowrate) * _minStreamTime;
        return
            calculatedPenalty < _minPenalty ? _minPenalty : calculatedPenalty;
    }

    function changePenaltyParameters(
        uint256 _newMinPenalty,
        uint256 _newStreamTine
    ) public onlyOwner {
        _minPenalty = _newMinPenalty;
        _minStreamTime = _newStreamTine;
    }

    function resetStream(
        address _superToken,
        address _sender,
        address _receiver
    ) internal {
        streams[_superToken][_sender][_receiver].flowRate = 0;
        streams[_superToken][_sender][_receiver].start = 0;
        streams[_superToken][_sender][_receiver].end = 0;
        streams[_superToken][_sender][_receiver].bufferAmount = 0;
        streams[_superToken][_sender][_receiver].claimPenaltyAvailable = 0;
        streams[_superToken][_sender][_receiver].penaltyAmount = 0;
    }

    function deleteFlow(
        address _sender,
        address _receiver,
        address _superToken
    ) public {
        require(
            streams[_superToken][_sender][_receiver].flowRate != 0,
            "There is no stream to be deleted"
        );

        ISuperfluidToken superToken = ISuperfluidToken(_superToken);

        uint256 _endStreamTime = streams[_superToken][_sender][_receiver].end;
        uint256 _endBufferTime = streams[_superToken][_sender][_receiver]
            .claimPenaltyAvailable;
        uint256 _paybackTotal = 0;

        if (block.timestamp <= _endBufferTime) {
            require(
                _sender == msg.sender,
                "Only owner can delete flow right now!"
            );

            uint256 _paybackPenalty = streams[_superToken][_sender][_receiver]
                .penaltyAmount;

            if (block.timestamp <= _endStreamTime) {
                uint256 _paybackStream = calculateRemainingStream(
                    _sender,
                    _receiver,
                    _superToken
                );
                uint256 _paybackBuffer = streams[_superToken][_sender][
                    _receiver
                ].bufferAmount;
                _paybackTotal =
                    _paybackPenalty +
                    _paybackBuffer +
                    _paybackStream;
            }

            if (
                (block.timestamp > _endStreamTime) &&
                (block.timestamp <= _endBufferTime)
            ) {
                uint256 _paybackBuffer = calculateRemainingBuffer(
                    _sender,
                    _receiver,
                    _superToken
                );
                _paybackTotal = _paybackPenalty + _paybackBuffer;
            }

            // update balance and reset stream struct
            availableSFTokenBalances[_superToken][
                msg.sender
            ] = availableSFTokenBalances[_superToken][msg.sender].add(
                _paybackTotal
            );
            resetStream(_superToken, _sender, _receiver);
            // cancel flow
            cfaV1.deleteFlow(address(this), _receiver, superToken);
            emit StreamCanceled(_superToken, _sender, _receiver);
        } else {
            _paybackTotal = calculateRemainingPenalty(
                _sender,
                _receiver,
                _superToken
            );
            // update balance and reset stream struct
            availableSFTokenBalances[_superToken][
                msg.sender
            ] = availableSFTokenBalances[_superToken][msg.sender].add(
                _paybackTotal
            );
            resetStream(_superToken, _sender, _receiver);
            // cancel flow
            cfaV1.deleteFlow(address(this), _receiver, superToken);
            emit StreamCanceled(_superToken, _sender, _receiver);
        }
    }

    function calculateRemainingStream(
        address _sender,
        address _receiver,
        address _superToken
    ) internal returns (uint256) {
        uint256 _timeNow = block.timestamp;
        uint256 _startTime = streams[_superToken][_sender][_receiver].start;
        uint256 _endTime = streams[_superToken][_sender][_receiver].end;
        uint256 _flowRate = uint256(
            streams[_superToken][_sender][_receiver].flowRate
        );
        uint256 _amountSent = ((_timeNow - _startTime) * _flowRate);
        uint256 _originalAmountToSend = ((_endTime - _startTime) * _flowRate);
        return (_originalAmountToSend - _amountSent);
    }

    function calculateRemainingBuffer(
        address _sender,
        address _receiver,
        address _superToken
    ) internal returns (uint256) {
        uint256 _timeNow = block.timestamp;
        uint256 _endTime = streams[_superToken][_sender][_receiver].end;
        uint256 _flowRate = uint256(
            streams[_superToken][_sender][_receiver].flowRate
        );
        return ((_timeNow - _endTime) * _flowRate);
    }

    function calculateRemainingPenalty(
        address _sender,
        address _receiver,
        address _superToken
    ) internal returns (uint256) {
        uint256 _penalty = streams[_superToken][_sender][_receiver]
            .penaltyAmount;
        uint256 _flowRate = uint256(
            streams[_superToken][_sender][_receiver].flowRate
        );
        uint256 _endBufferTime = streams[_superToken][_sender][_receiver]
            .claimPenaltyAvailable;
        return (_penalty - ((block.timestamp - _endBufferTime) * _flowRate));
    }
}
