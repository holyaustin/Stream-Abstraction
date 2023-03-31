"""
Streaming part by haraslub;

"""

from brownie import config, network, interface, Contract, ThelsStream
from web3 import Web3


def get_thels_contract():
    """
    Get existing (= deployed) THELS contract from config file
    """
    print("Getting THELS contract ...")
    thels_contract_address = config["networks"][network.show_active()]["thels_contract"]
    thels_contract = None
    if thels_contract_address:
        thels_contract = Contract.from_abi(
            "ThelsStream", thels_contract_address, ThelsStream.abi
        )
    return thels_contract


def approve_erc20(
    amount, 
    spender, 
    erc20_address, 
    owner
    ):
    """
    amount: erc20 token amount to be approved
    spender: thels contract address
    erc20_address: contract address of the ERC20 token
    owner: owner of tokens = signer of transaction
    """
    print("\nApproving ERC20 token ...")
    erc20 = interface.IERC20(erc20_address)
    tx = erc20.approve(spender, amount, {"from": owner})
    tx.wait(1)
    print("Approved!")
    return tx


def deposit_erc20_to_thels_contract(
    thels_contract, 
    erc20token_address, 
    AMOUNT_TO_APPROVE, 
    owner
    ):
    """
    Deposit already approved erc20 tokens to Thels contract.
    
    thels_contract: address of thels deployed contract
    erc20token_address: contract address of the ERC20 token
    AMOUNT_TO_APPROVE: amount fo tokens to approve (streaming amount + buffer + penalty)
    owner: signer of the transaction
    """
    # thels_contract = get_thels_contract()
    thels_contract.depositErc20(
            erc20token_address, 
            AMOUNT_TO_APPROVE,
            {
                "from": owner, 
                "gas_limit": 10000000, # needed to set it manually as it keeps failing
                "allow_revert": True # needed to set it manually as it keeps failing
            },
        )


def withdraw_erc20_from_thels_contract(
    thels_contract, 
    owner, 
    erc20token_address, 
    amount_to_withdraw=None
    ):
    """
    thels_contract: address of thels deployed contract
    owner: owner of tokens, signer of transaction
    erc20token_address: contract address of tokens to be withdrawn
    amount_to_withdraw: amount of tokens to be withdrawn, if not defined
        all owner's balance is going to be withdrawn 
    """
    # thels_contract = get_thels_contract()
    if amount_to_withdraw == None:
        amount_to_withdraw = thels_contract.getErc20TokenBalance(
            owner, 
            erc20token_address, 
            {"from": owner},
        )
    thels_contract.withdrawErc20(
        owner, 
        erc20token_address, 
        amount_to_withdraw, 
        {"from": owner},
    )


def upgrade_erc20_to_superfluid_token(
    thels_contract, 
    erc20token_address, 
    superfluid_token_address, 
    AMOUNT_TO_UPGRADE, 
    owner
    ):
    """
    thels_contract: address of thels deployed contract
    erc20token_address: contract address of the ERC20 token (for instance DAI)
    superfluid_token_address: contract of superfluid token (for instance DAIx)
    AMOUNT_TO_UPGRADE: amount fo tokens to UPGRADE (streaming amount + buffer + penalty)
    """
    # thels_contract = get_thels_contract()
    thels_contract.upgradeToken(
            erc20token_address, 
            superfluid_token_address,
            AMOUNT_TO_UPGRADE,
            {"from": owner},
        )


def downgrade_superfluid_to_erc20_token(
    thels_contract, 
    owner, 
    superfluid_token_address, 
    erc20token_address
    ):
    """
    thels_contract: address of thels deployed contract
    owner: owner of tokens
    superfluid_token_address: sf token to be downgraded
    erc20token_address: erc20 token to be received
    """
    # thels_contract = get_thels_contract()
    amount_to_downgrade = thels_contract.getSFTokenBalance(
            owner, 
            superfluid_token_address, 
            {"from": owner},
            )  
    thels_contract.downgradeToken(
        erc20token_address, 
        superfluid_token_address,
        amount_to_downgrade,
        {"from": owner},
        )


def change_penalty_parameters(
    thels_contract, 
    owner, 
    MIN_PENALTY_NEW, 
    MIN_STREAM_TIME
    ):
    """
    thels_contract: address of thels deployed contract
    owner: owner of the Thels Contract can only use this function
    MIN_PENALTY_NEW: new minimum of fine/penalty to be paid if stream is not cancelled on time
    MIN_STREAM_TIME: new minimal required time of streaming
    """
    # thels_contract = get_thels_contract()
    thels_contract.changePenaltyParameters(
            MIN_PENALTY_NEW,
            MIN_STREAM_TIME,
            {"from": owner}
        )


def start_stream(
    thels_contract,
    owner, 
    receiver, 
    superfluid_token_address, 
    FLOW_RATE, 
    BUFFER_TIME_IN_SEC, 
    STREAMING_PERIOD_IN_SEC
    ):
    """
    thels_contract: address of thels deployed contract
    owner: signer = sender who is going to stream 
    receiver: a receiver address (the final destination of the stream)
    superfluid_token_address: superfluid token address which is going to be streamed
    FLOW_RATE: WEI/SEC
    BUFFER_TIME_IN_SEC: buffer time, all owner should calculate it by its own risk curve
    STREAMING_PERIOD_IN_SEC: time of streaming
    """
    # thels_contract = get_thels_contract()
    thels_contract.startStream(
            receiver, 
            superfluid_token_address, 
            FLOW_RATE,
            BUFFER_TIME_IN_SEC,
            STREAMING_PERIOD_IN_SEC,
            {"from": owner},
        )


def cancel_stream(
    thels_contract, 
    owner, 
    receiver, 
    superfluid_token_address
    ):
    """
    thels_contract: address of thels deployed contract
    owner: signer = sender who is the source of streaming
    receiver: a receiver address (the final destination of the stream)
    superfluid_token_address: superfluid token address which is streamed
    """
    # thels_contract = get_thels_contract()
    thels_contract.deleteFlow(
        owner, 
        receiver, 
        superfluid_token_address, 
        {"from": owner},
    )

