import json, pytest
from scripts.utils import tx_param, DEPLOYER
from brownie import interface, chain, CurveFxRouter, accounts


def get_tokens():
    with open("tests/tokens.json") as json_file:
        tokens = json.load(json_file)
    return tokens


def fill_wallet_with_underlying(underlying, recipient, amount, giver):
    underlying.transfer(recipient, amount, tx_param(giver))


def clean_account(tokenIn, tokenOut, alice):
    bob = accounts[1]
    tokenIn.transfer(bob, tokenIn.balanceOf(alice), tx_param(alice))
    tokenOut.transfer(bob, tokenOut.balanceOf(alice), tx_param(alice))


@pytest.mark.parametrize(
    tuple(get_tokens()[0]), [tuple(dct.values()) for dct in get_tokens()]
)
def test_integration(a, symbol, address, pool, derivative, whale):
    chain.snapshot()
    alice = a[0]
    router = CurveFxRouter.deploy(tx_param(DEPLOYER))
    tokens = get_tokens()

    for token in tokens:
        if symbol == token["symbol"]:
            continue

        print("SWAPPING -- ", symbol, " -> ", token["symbol"])

        tokenIn = interface.ERC20(address)
        tokenOut = interface.ERC20(token["address"])
        amountIn = 10 ** tokenIn.decimals()
        if symbol == "jJPY" or symbol == "JPY":
            amountIn = 100 * 10 ** tokenIn.decimals()

        fill_wallet_with_underlying(tokenIn, alice, amountIn, whale)
        args = (derivative, token["pool"], token["derivative"])
        tokenIn.approve(router, amountIn, tx_param(alice))
        before = tokenOut.balanceOf(alice)
        router.exchange(
            tokenIn,
            tokenOut,
            amountIn,
            0.002e18,
            args,
            tx_param(alice),
        )

        # No dust
        assert tokenIn.balanceOf(router) == 0
        assert tokenOut.balanceOf(router) == 0

        # TODO:  assert Exchange Rates

        print(
            "Received",
            (tokenOut.balanceOf(alice) - before) / 10 ** tokenOut.decimals(),
        )
        clean_account(tokenIn, tokenOut, alice)

    chain.reset()
