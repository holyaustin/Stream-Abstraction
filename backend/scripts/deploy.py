from brownie import Thels, config, network, Contract
from brownie.network.account import Account

from scripts.helpful_scripts import get_account, get_contract


def deploy(account: Account = get_account()):
    return Thels.deploy(
        get_contract("usdc_token"),
        get_contract("usdcx_token"),
        get_contract("superfluid_host"),
        get_contract("uniswap_router"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def allow_uni(thels: Contract, account: Account = get_account()):
    thels.allowToken(
        get_contract("uni_token").address,
        get_contract("uni_usd_price_feed").address,
        800,
        {"from": account},
    )


def main():
    account = get_account()

    # Deploy the contract
    print("Deploying Thels contract...")
    thels = deploy(account)
    print("Deployed.")

    # Add UNI to allowed tokens
    print("Adding UNI as an allowed token...")
    allow_uni(thels, account)
    print("Added.")
