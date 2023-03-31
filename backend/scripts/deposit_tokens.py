from brownie import Thels, Contract
from brownie.network.account import Account

from scripts.helpful_scripts import get_account, get_contract


def approve_token(thels: Contract, token: str, account: Account = get_account()):
    token = get_contract(token)
    tx = token.approve(thels.address, (2 ** 256) - 1, {"from": account})
    tx.wait(1)
    return tx


def deposit_token(thels: Contract, token: str, amount: int, account=get_account()):
    token = get_contract(token)
    tx = thels.deposit(token.address, amount, {"from": account})
    tx.wait(1)
    return tx


def withdraw_token(thels: Contract, token: str, amount: int, account=get_account()):
    token = get_contract(token)
    tx = thels.withdraw(token.address, amount, {"from": account})
    tx.wait(1)
    return tx


def lend_usdc(thels: Contract, amount: int, account=get_account()):
    tx = thels.convertToUSDCx(amount, {"from": account})
    tx.wait(1)
    return tx


def withdraw_usdc(thels: Contract, amount: int, account=get_account()):
    tx = thels.convertToUSDC(amount, {"from": account})
    tx.wait(1)
    return tx


def main():
    account = get_account()

    # Approve UNI
    print("Approving UNI...")
    approve_token(Thels[-1], "uni_token", account)
    print("Approved.")

    # Deposit UNI
    print("Depositing UNI...")
    deposit_token(Thels[-1], "uni_token", 10 * 10 ** 18, account)
    print("Deposited.")

    # Approve USDC
    print("Approving USDC...")
    approve_token(Thels[-1], "usdc_token", account)
    print("Approved.")

    # Lend USDC
    print("Lending USDC...")
    lend_usdc(Thels[-1], 100 * 10 ** 18, account)
    print("Lent.")
