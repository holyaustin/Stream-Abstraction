"""
Helpers for streaming part

"""

from brownie import (
    accounts, network, config
)
from web3 import Web3


DECIMALS = 18 
INITIAL_VALUE = Web3.toWei(2000, "ether")

NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["hardhat", "development", "ganache"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + [
    "mainnet-fork",
]

dict_erc20_tokens = {
    "rinkeby": {
        "USDC": "0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2",
        "TUSD": "0xA794C9ee519FD31BbCE643e8D8138f735E97D1DB",
        "DAI": "0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7",
        "DAIx": "0x745861AeD1EEe363b4AaA5F1994Be40b1e05Ff90",
    },
    "polygon-test": {
        "DAIx": "0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f",
    }
}


def get_account(index=None, id=None):
    """
    Get account (private key) to work with

    Args:
        index (int): index of account in a local ganache
        id (string): name of the account from 'brownie accounts list'

    Returns: 
        (string): private key of the account
    """
    if index:
        return accounts[index]  # use account with defined index from local ganache
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[0]  # use the first ganache account
    if id:
        return accounts.load(id)    # use users's defined account in 'brownie accounts list' (id=name)
    return accounts.add(config["wallets"]["from_key"])  # use account from our environment


