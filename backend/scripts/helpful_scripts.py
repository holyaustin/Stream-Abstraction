from brownie import (
    MockV3Aggregator,
    MockToken,
    MockSuperToken,
    MockSuperfluid,
    network,
    accounts,
    config,
    Contract,
)
from brownie.network.account import Account

LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development"]
CONTRACT_TO_MOCK = {
    "uni_token": [MockToken, 0],
    "usdc_token": [MockToken, 1],
    "usdcx_token": [MockSuperToken, 0],
    "uni_usd_price_feed": [MockV3Aggregator, 0],
    "superfluid_host": [MockSuperfluid, 0],
    "uniswap_router": [None, 0],
}


def get_account(index: int = None, id=None) -> Account:
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


def get_contract(contract_name: str) -> Contract:
    contract_type = CONTRACT_TO_MOCK[contract_name][0]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        if len(contract_type) <= 0:
            deploy_mocks()
        contract = contract_type[CONTRACT_TO_MOCK[contract_name][1]]
    else:
        if contract_type is None:
            return Contract.from_explorer(
                config["networks"][network.show_active()][contract_name]
            )
        contract_address = config["networks"][network.show_active()][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )
    return contract


def deploy_mocks():
    account = get_account()
    MockV3Aggregator.deploy(18, 12 * 10 ** 18, {"from": account})  # UNI Token, 10 USD
    MockToken.deploy(100000 * 10 ** 18, "Fake Uniswap Token", "fUNI", {"from": account})
    MockToken.deploy(100000 * 10 ** 18, "Fake USD Coin", "fUSDC", {"from": account})
    MockSuperfluid.deploy(False, False, {"from": account})
    MockSuperToken.deploy(MockSuperfluid[0], 0, {"from": account})
