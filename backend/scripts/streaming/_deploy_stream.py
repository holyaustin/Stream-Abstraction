"""
Streaming part by haraslub;

"""
from scripts._helpers import get_account, dict_erc20_tokens
from scripts._stream_functions import (
    approve_erc20, deposit_erc20_to_thels_contract, withdraw_erc20_from_thels_contract,
    upgrade_erc20_to_superfluid_token, downgrade_superfluid_to_erc20_token,
    change_penalty_parameters,
    start_stream, cancel_stream
)
from brownie import config, network, Contract, ThelsStream, interface
from web3 import Web3
import time
from datetime import datetime


def main():
    # set variables streaming parameters:
    AMOUNT_TO_STREAM = Web3.toWei(100, "ether")
    STREAMING_PERIOD_IN_SEC = (24*3600)
    FLOW_RATE = AMOUNT_TO_STREAM / STREAMING_PERIOD_IN_SEC

    # calculate buffer
    BUFFER_TIME_IN_SEC = (4*3600)
    BUFFER_AMOUNT = BUFFER_TIME_IN_SEC * FLOW_RATE

    # calculate penalty
    MIN_STREAMING_TIME = (1*3600) # need to be change
    PENALTY = max(Web3.toWei(10, "ether"), FLOW_RATE*MIN_STREAMING_TIME)

    # total amount to approve / upgrade
    AMOUNT_TO_APPROVE = AMOUNT_TO_STREAM + BUFFER_AMOUNT + PENALTY  
    
    # set accounts
    owner = get_account()
    receiver = "0x5a4391C5176412acc583ab378881070aA9963cA1" # for testing

    # get or deploy contract
    stream_contract = init_phase(owner)

    erc20token_address = dict_erc20_tokens[network.show_active()]["DAI"]
    superfluid_token_address = dict_erc20_tokens[network.show_active()]["DAIx"]

    # Check balances first
    get_user_balance(owner, "at the beggining", erc20token_address)

    TEST_01 = input_operation("TEST")
    if TEST_01.lower() == "y":
        get_inner_calc_results(owner, stream_contract, FLOW_RATE, STREAMING_PERIOD_IN_SEC, BUFFER_TIME_IN_SEC)

    APPROVE = input_operation("APPROVE TOKENS")
    if APPROVE.lower() == "y":
        approve_erc20(AMOUNT_TO_APPROVE, stream_contract.address, erc20token_address, owner)
        get_user_balance(owner, "after approval", erc20token_address)

    DEPOSIT = input_operation("DEPOSIT TOKENS")
    if DEPOSIT.lower() == "y":
        print("\nFunding contract ...")
        deposit_erc20_to_thels_contract(
            stream_contract,
            erc20token_address,
            AMOUNT_TO_APPROVE,
            owner,
        )
        # stream_contract.depositErc20(
        #     erc20token_address, 
        #     AMOUNT_TO_APPROVE, 
        #     {"from": owner, "gas_limit": 10000000, "allow_revert": True}
        #     )
    
    CHECK_BAL_01 = input_operation("... CHECK BALANCES")
    if CHECK_BAL_01.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after deposit", erc20token_address)
    
    UPGRADE = input_operation("UPGRADE FROM ERC20 TO SF TOKENS")
    if UPGRADE.lower() == "y":
        print("\nUpgrading token ...")
        upgrade_erc20_to_superfluid_token(
            stream_contract,
            erc20token_address,
            superfluid_token_address,
            AMOUNT_TO_APPROVE,
            owner,
        )
        # stream_contract.upgradeToken(
        #     erc20token_address, 
        #     superfluid_token_address,
        #     AMOUNT_TO_APPROVE,
        #     {"from": owner}
        #     )
    
    CHECK_BAL_02 = input_operation("... CHECK BALANCES")
    if CHECK_BAL_02.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after upgrade", erc20token_address)
    
    CHANGE_PARAMETERS = input_operation("CHANGE PARAMETERS")
    if CHANGE_PARAMETERS.lower() == "y":
        print("\nChanging parameters ... ")
        MIN_PENALTY_NEW = Web3.toWei(10, "ether")
        MIN_STREAM_TIME = (1*3600)
        print("... new penalty minimum: {} TOKEN\n... new min stream time: {} SEC".format(
            Web3.fromWei(MIN_PENALTY_NEW, "ether"), MIN_STREAM_TIME
        ))
        change_penalty_parameters(
            stream_contract,
            owner,
            MIN_PENALTY_NEW,
            MIN_STREAM_TIME, 
        )
        # stream_contract.changePenaltyParameters(
        #     MIN_PENALTY_NEW,
        #     MIN_STREAM_TIME,
        #     {"from": owner})
    
    TEST_01 = input_operation("TEST")
    if TEST_01.lower() == "y":
        get_inner_calc_results(owner, stream_contract, FLOW_RATE, STREAMING_PERIOD_IN_SEC, BUFFER_TIME_IN_SEC)
    
    START_STREAM = input_operation("START STREAM")
    if START_STREAM.lower() == "y":
        print("\nStart streaming to {}".format(receiver))
        start_stream(
            stream_contract,
            owner,
            receiver,
            superfluid_token_address,
            FLOW_RATE,
            BUFFER_TIME_IN_SEC,
            STREAMING_PERIOD_IN_SEC,
        )
        # stream_contract.startStream(
        #     receiver, 
        #     superfluid_token_address, 
        #     FLOW_RATE,
        #     BUFFER_TIME_IN_SEC,
        #     STREAMING_PERIOD_IN_SEC,
        #     {"from": owner})
    
    INFO_STREAM_01 = input_operation("... GET INFO ABOUT STREAM")
    if INFO_STREAM_01.lower() == "y":
        get_stream_info(stream_contract, superfluid_token_address, owner, receiver)

    CHECK_BAL_STREAM = input_operation("... CHECK BALANCES")
    if CHECK_BAL_STREAM.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after starting a stream", erc20token_address)
    
    WAIT_FOR_STREAM = input_operation("WAIT SOME TIME TO LET IT STREAM")
    if WAIT_FOR_STREAM == "y":
        TIME_TO_WAIT = input("Default time is set to 300 sec. Hit Y if agreed, or insert seconds: ")
        if TIME_TO_WAIT == "y":
            TIME_TO_WAIT = 300
        else:
            TIME_TO_WAIT = int(TIME_TO_WAIT)
        print("Waiting for {} sec ... (to send at least something)".format(TIME_TO_WAIT))
        time.sleep(TIME_TO_WAIT)
    
    CANCEL_STREAM = input_operation("CANCEL STREAMING")
    if CANCEL_STREAM.lower() == "y":
        print("\nCancel streaming to address: {}".format(receiver))
        cancel_stream(
            stream_contract,
            owner,
            receiver,
            superfluid_token_address,
        )
        # stream_contract.deleteFlow(owner, receiver, superfluid_token_address, {"from": owner})

    INFO_STREAM_02 = input_operation("... GET INFO ABOUT STREAM")
    if INFO_STREAM_02.lower() == "y":
        get_stream_info(stream_contract, superfluid_token_address, owner, receiver)
    
    CHECK_BAL_STREAM_AGAIN = input_operation("... CHECK BALANCES")
    if CHECK_BAL_STREAM_AGAIN.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after starting a stream", erc20token_address)
    
    DOWNGRADE = input_operation("DOWNGRADE FROM SF TO ERC20 TOKENS")
    if DOWNGRADE.lower() == "y":
        print("\nDowngrading token ...")
        downgrade_superfluid_to_erc20_token(
            stream_contract,
            owner,
            superfluid_token_address,
            erc20token_address,
        )
        # amount_to_downgrade = stream_contract.getSFTokenBalance(
        #     owner, 
        #     superfluid_token_address, 
        #     {"from": owner}
        #     )
        # print("Total amounts of SF tokens to be downgraded: {}".format(
        #     Web3.fromWei(amount_to_downgrade, "ether")
        #     ))
        # stream_contract.downgradeToken(
        #     erc20token_address, 
        #     superfluid_token_address,
        #     amount_to_downgrade,
        #     {"from": owner}
        #     )
    
    CHECK_BAL_03 = input_operation("... CHECK BALANCES")
    if CHECK_BAL_03.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after downgrade", erc20token_address)

    WITHDRAW = input_operation("WITHDRAW DEPOSITED ERC20 TOKENS")
    if WITHDRAW.lower() == "y":
        print("\nWithdrawing all deposited amount")
        withdraw_erc20_from_thels_contract(
            stream_contract,
            owner,
            erc20token_address
        )
        # amount_to_withdraw = stream_contract.getErc20TokenBalance(owner, erc20token_address, {"from": owner})
        # stream_contract.withdrawErc20(owner, erc20token_address, amount_to_withdraw, {"from": owner})
    
    CHECK_BAL_04 = input_operation("... CHECK BALANCES")
    if CHECK_BAL_04.lower() == "y":
        get_balances(owner, stream_contract, erc20token_address, superfluid_token_address)
        get_user_balance(owner, "after withdrawal", erc20token_address)
    


def init_phase(account):
    stream_contract_address = input("\nInsert contract address or hit enter to deploy the new contract: ")
    if stream_contract_address:
        print("\nInserted contract address: {},\n... thus going to get contract from ABI.".format(stream_contract_address))
        stream_contract = Contract.from_abi(
            "ThelsStream", stream_contract_address, ThelsStream.abi
        )
    else:
        print("\nDeploying contract ...")
        host_address = config["networks"][network.show_active()]["superfluid_host"]
        print("SuperFluid host address for {} newtork: {}\n".format(network.show_active(), host_address))
        stream_contract = ThelsStream.deploy(
            host_address,
            {
                "from": account, 
                "gas_limit": 10000000, 
                "allow_revert": True,
                },
            # publish_source=config["networks"][network.show_active()].get("verify", False)
            )
    return stream_contract


def get_balances(account, stream_contract, erc20token_address, superfluid_token_address):
    print("\nGetting balances of the contract ...")
    erc20_balance = stream_contract.getErc20TokenBalance(account, erc20token_address, {"from": account})
    superfluid_balance = stream_contract.getSFTokenBalance(account, superfluid_token_address, {"from": account})
    print("Actual balance of ERC20 in the contract: {}".format(Web3.fromWei(erc20_balance, "ether")))
    print("Actual balance of SUPERFLUID in the contract: {}".format(Web3.fromWei(superfluid_balance, "ether")))


def get_user_balance(account, message, erc20token_address):
    user_balance = interface.IERC20(erc20token_address).balanceOf(account)
    print("\nUser {} has erc20 token balance ({}): {}".format(account, message, Web3.fromWei(user_balance, "ether")))


def input_operation(method_name):
    operation = input("\n{}? Y for YES, or press enter: ".format(method_name))
    return operation


def get_stream_info(stream_contract, superfluid_token_address, owner, receiver):
    print("\nGetting actual stream info ...")
    stream = stream_contract.getStream(superfluid_token_address, owner, receiver)
    (ext_flow_rate, ext_start_timestamp, ext_end_timestamp, ext_buffer_amount, ext_penalty_date, ext_penalty_amount) = stream
    print("Start date of the stream (UTC): {}\nEnd date of the stream (UTC): {}\nPenalty date (UTC): {}".format(
        datetime.utcfromtimestamp(ext_start_timestamp).strftime("%Y-%m-%d %H:%M:%S"), 
        datetime.utcfromtimestamp(ext_end_timestamp).strftime("%Y-%m-%d %H:%M:%S"), 
        datetime.utcfromtimestamp(ext_penalty_date).strftime("%Y-%m-%d %H:%M:%S"), 
    ))
    print("Flow rate: {} TOKEN/SEC\nBuffer amount: {} TOKEN\nPenalty amount: {} TOKEN".format(
        Web3.fromWei(ext_flow_rate, "ether"), 
        Web3.fromWei(ext_buffer_amount, "ether"), 
        Web3.fromWei(ext_penalty_amount, "ether")
    ))


def get_inner_calc_results(owner, stream_contract, FLOW_RATE, STREAMING_PERIOD_IN_SEC, BUFFER_TIME_IN_SEC):
    calc_stream_amt = stream_contract.calculateStreamAmount(FLOW_RATE, STREAMING_PERIOD_IN_SEC, {"from": owner})
    calc_stream_buf = stream_contract.calculateBuffer(FLOW_RATE, BUFFER_TIME_IN_SEC, {"from": owner})
    calc_stream_pen = stream_contract.calculatePenalty(FLOW_RATE, {"from": owner})
    print("Calculated stream amount: {}".format(Web3.fromWei(calc_stream_amt, "ether")))
    print("Calculated stream buffer: {}".format(Web3.fromWei(calc_stream_buf, "ether")))
    print("Calculated stream penalty: {}".format(Web3.fromWei(calc_stream_pen, "ether")))
    print("All together: {}".format(Web3.fromWei(calc_stream_amt + calc_stream_buf + calc_stream_pen, "ether")))