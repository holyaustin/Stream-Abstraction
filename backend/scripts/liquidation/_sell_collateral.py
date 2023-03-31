# I have some issues:

# 1) Need to somehow get the borrower's address in liquidation function in solidity contract
# 2) Need Thels's address to connect Uniswap
# 3) Idk what is meant by qty, but it asks for it
# 4) Need to do a check if the the money have been transfered
# 5) As u can see, it uses Web3 (the example version) instead of Brownie
# 6) Uniswap must be installed, I think we can import it from here https://github.com/uniswap-python/uniswap-python/blob/master/uniswap/uniswap.py

from brownie import Contract
from web3 import Web3
from uniswap import Uniswap

from scripts.helpful_scripts import get_account, get_contract

uni = Web3.toChecksumAddress("0xe44FCEA92aDe7950e1b5FbEbb2647210Cd0F79f2 ")
usdc = Web3.toChecksumAddress("0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2")


def sell_collateral_uni_usdc(
    thels: Contract, token: str, amount: int, account=get_account()
):
    # Checks impact for a pool with very little liquidity.
    # This particular route caused a $14k loss for one user: https://github.com/uniswap-python/uniswap-python/discussions/198
    uniswap = Uniswap(address=None, private_key=None, version=3)  # Thels address
    token = get_contract(token)
    tx = thels.liquidate(token.address, amount, {"from": account})
    tx.wait(1)
    # check if the the money have been transfered
    qty = (
        1 * 10 ** 18
    )  # idk what it is, but it was in the example with buying VXV with ETH
    uniswap_trade = uniswap.make_trade(uni, usdc, qty)
    return uniswap_trade


# https://github.com/uniswap-python <- library
