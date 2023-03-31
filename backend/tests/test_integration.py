import time

from scripts.helpful_scripts import (
    get_account,
    get_contract,
)

from scripts.deploy import deploy, allow_uni
from scripts.deposit_tokens import (
    approve_token,
    deposit_token,
    withdraw_token,
    lend_usdc,
    withdraw_usdc,
)

UNI_AMOUNT = 3 * 10 ** 18
USDC_AMOUNT = 50 * 10 ** 18


def test_overall():
    # Arrange
    account = get_account()
    thels = deploy()
    allow_uni(thels, account)
    approve_token(thels, "usdc_token", account)
    approve_token(thels, "uni_token", account)

    # Act / Assert
    deposit_token(thels, "uni_token", UNI_AMOUNT, account)
    assert thels.getCollateralValue(account) >= UNI_AMOUNT * 10
    assert thels.getCollateralValue(account) * 0.8 == thels.getBorrowableAmount(account)

    lend_usdc(thels, USDC_AMOUNT, account)
    assert thels.lendAmounts(account) == USDC_AMOUNT
    assert thels.getTotalUSDCx() == USDC_AMOUNT

    thels.startStream(
        account, 10 * 10 ** 10, int(time.time()) + 10 ** 8, {"from": account}
    ).wait(10)
    assert thels.borrowAmounts(account) >= 9 * 10 ** 18

    thels.stopStream(account, {"from": account}).wait(1)
    assert thels.lendAmounts(account) > USDC_AMOUNT

    thels.repay(thels.borrowAmounts(account), {"from": account}).wait(1)
    assert thels.borrowAmounts(account) == 0
    assert thels.getTotalUSDCx() > USDC_AMOUNT

    withdraw_token(thels, "uni_token", UNI_AMOUNT, account)
    assert thels.depositAmounts(account, get_contract("uni_token").address) == 0

    withdraw_usdc(thels, thels.lendAmounts(account), account)
    assert thels.lendAmounts(account) == 0
