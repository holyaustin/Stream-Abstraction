from brownie import MockToken, config, network
from brownie.network.account import Account

from scripts.helpful_scripts import get_account


def deploy(account: Account = get_account()):
    return MockToken.deploy(
        100000 * 10 ** 18,
        "Fake Uniswap Token",
        "fUNI",
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def main():
    account = get_account()

    # Deploy the contract
    print("Deploying Fake Uniswap Token contract...")
    deploy(account)
    print("Deployed.")
