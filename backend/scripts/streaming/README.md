# thels

The loan stream

## Streaming part explained

### General info

Development and testing was performed on rinkeby testnet due to initial problems with deployment on the polygon mumbai testnet. In particular, when depositing to the contract (see function deposit_erc20_to_thels_contract) on the mumbai, brownie kept reverting it (even I had gas_limit set and auto_revert as well). I gave up and continued on the rinkeby testnet.

## Thels Stream explained / example

DAO deposits (`depositErc20` in the contract) ERC20 token (DAI in particular) to the contract (I needed to somehow get ERC20 token to the contract in order to be able continue in the development). Before deposit, DAO needs to approve it. 

The total amount of tokens for approval/deposit is calculated by sum of:

**TOTAL_AMOUNT = AMOUNT TO STREAM + BUFFER + PENALTY**

- Amount to be streamed;
- Amount to buffer (DAO decides how much they will choose buffer in order to have enough time to stop streaming). See function `calculateBuffer` in the contract how the buffer can be calculated.
- Penalty (penalty is open to everyone, if DAO does not close the stream on time, i.e. before buffer expires; penalty parameters can be changed by owner of the thels contract). See `calculatePenalty` in the contract how the penalty is calculated.

DAO upgrades all deposited ERC20 tokens to Superfluid tokens (`upgradeToken` in the contract). 

DAO initiate stream (`startStream` in the contract).

DAO cancels stream (`deleteFlow` in the contract). If DAO does that on time, buffer and penalty is refunded.

---

You can test all together by yourself running **_deploy_stream.py** Do not forget set `receiver` (line 37) to your another wallet to be able to stream to it. The example has following steps:

1. deploy thels contract;
2. approve erc20 tokens;
3. deposit erc20 tokens;
4. upgrade erc20 tokens to superfluid tokens;
5. change penalty parameters, i.e. min penalty amount to 10 USDC and min streaming period to 1 day (initial values are set to min penalty amount = 1000 USDC, and min streaming period 7 day);
6. start stream;
7. cancel stream;
8. downgrade from superfluid tokens to erc20 tokens;
9. withdraw tokens back to your wallet;
