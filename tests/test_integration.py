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


EURS = "0xE111178A87A3BFf0c8d18DECBa5798827539Ae99"
FACTORY_REGISTRY = "0x722272D36ef0Da72FF51c5A65Db7b870E2e8D4ee"
META_POOL = "0x447646e84498552e62eCF097Cc305eaBFFF09308"

PAR = "0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128"

jEUR = "0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c"
jCAD = "0x8ca194A3b22077359b5732DE53373D4afC11DeE3"
jSGD = "0xa926db7a4CC0cb1736D5ac60495ca8Eb7214B503"

poolJeur = "0xCbbA8c0645ffb8aA6ec868f6F5858F2b0eAe34DA"
poolJCAD = "0x09757F36838AAACD47DF9de4D3f0AdD57513531f"
poolSGD = "0x91436EB8038ecc12c60EE79Dfe011EdBe0e6C777"

derivativeCAD = "0x606Ac601324e894DC20e0aC9698cCAf180960456"
derivativeEUR = "0x0Fa1A6b68bE5dD9132A09286a166d75480BE9165"
derivativeSGD = "0xb6C683B89228455B15cF1b2491cC22b529cdf2c4"


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
        if symbol == "jJPY":
            amountIn = 100 * 10 ** tokenIn.decimals()
        # try:
        fill_wallet_with_underlying(tokenIn, alice, amountIn, whale)
        args = (derivative, token["pool"], token["derivative"])
        tokenIn.approve(router, amountIn, tx_param(alice))
        before = tokenOut.balanceOf(alice)
        router.exchange(
            tokenIn,
            tokenOut,
            amountIn,
            args,
            tx_param(alice),
        )
        print(
            "Received",
            (tokenOut.balanceOf(alice) - before) / 10 ** tokenOut.decimals(),
        )
        clean_account(tokenIn, tokenOut, alice)
        # except:
        # print("ERROR -- ", symbol, " -> ", token["symbol"])

    chain.reset()
