// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";

contract ThelsLiquidation {
    ISuperToken public USDCxToken;
    struct Token {
        address tokenAddress;
        AggregatorV3Interface priceFeed; // Chainlink price feed
        uint256 borrowPercent; // 100 => 10.0%
    }

    event SoldCollateral(
        address indexed borrower,
        address token,
        uint256 amount
    );
    mapping(address => Token) public allowedTokens; // mapping that shows if a token can be used as collateral
    mapping(address => uint256) public borrowAmounts; // USDC borrow amount of each user
    mapping(address => mapping(address => uint256)) public depositAmounts; // tokens and deposit amounts of each user
    address[] public allowedTokenList; // list of tokens that can be used as collateral

    // Liquidate borrower's token if the price of it drops below the borrowing amount
    function liquidate(address token, uint256 amount) public {
        // msg.sender supposed to be a borrower's address

        // Getting token price
        uint256 price = ((getTokenPrice(allowedTokens[token]) * amount) /
            (10**21)) *
            allowedTokens[token].borrowPercent +
            borrowAmounts[msg.sender];
        require(
            //check if collateral is worth of borrowed amount
            getBorrowableAmount(msg.sender) < price,
            "Token is worth of the debt"
        );
        require(amount > 0, "Amount of tokens to sell must be greater than 0");

        IERC20 _token = IERC20(amount);
        depositAmounts[msg.sender][token] -= amount;

        _token.transfer(msg.sender, amount);
        USDCxToken.upgrade(amount);
        emit SoldCollateral(msg.sender, token, amount);
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

    // returns the price in wei (10^18)
    function getTokenPrice(Token memory token) private view returns (uint256) {
        (, int256 price, , , ) = token.priceFeed.latestRoundData();
        return uint256(price) * 10**(18 - token.priceFeed.decimals());
    }
}
