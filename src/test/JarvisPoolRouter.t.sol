// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Vm.sol";
import "forge-std/stdlib.sol";

import {DSTestPlus} from "solfege/test/utils/DSTestPlus.sol";
import {MockERC20} from "solfege/test/utils/mocks/MockERC20.sol";
import {ERC20, SafeTransferLib} from "solfege/utils/SafeTransferLib.sol";

import {UtilsTest} from "src/test/Utils.sol";
import {JarvisPoolRouter, ISynthereumLiquidityPool} from "src/JarvisPoolRouter.sol";

contract JarvisPoolRouterTest is UtilsTest, stdCheats {
    using SafeTransferLib for ERC20;

    // Stablecoins
    address public constant EURS = 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99;
    address public constant PAR = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128;
    address public constant CADC = 0x5d146d8B1dACb1EBBA5cb005ae1059DA8a1FbF57;
    address public constant XSGD = 0x769434dcA303597C8fc4997Bf3DAB233e961Eda2;
    address public constant EURT = 0x7BDF330f423Ea880FF95fC41A280fD5eCFD3D09f;

    // jToken + Pool + Derivative
    // =========
    address public constant jEUR = 0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c;
    address public constant jCAD = 0x8ca194A3b22077359b5732DE53373D4afC11DeE3;
    address public constant jSGD = 0xa926db7a4CC0cb1736D5ac60495ca8Eb7214B503;

    address public constant poolJeur = 0xCbbA8c0645ffb8aA6ec868f6F5858F2b0eAe34DA;
    address public constant poolJCAD = 0x09757F36838AAACD47DF9de4D3f0AdD57513531f;
    address public constant poolSGD = 0x91436EB8038ecc12c60EE79Dfe011EdBe0e6C777;

    address public constant derivativeCAD = 0x606Ac601324e894DC20e0aC9698cCAf180960456;
    address public constant derivativeEUR = 0x0Fa1A6b68bE5dD9132A09286a166d75480BE9165;
    address public constant derivativeSGD = 0xb6C683B89228455B15cF1b2491cC22b529cdf2c4;
    // =========

    Vm public constant vm = Vm(HEVM_ADDRESS);

    JarvisPoolRouter router;

    function setUp() public {
        router = new JarvisPoolRouter();
    }

    function testExchange_SwapStableTojTokenSamePool() public {
        tip(jEUR, address(this), 1e18);

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            address(0),
            address(0),
            address(0)
        );

        ERC20(jEUR).safeApprove(address(router), 1e18);
        uint256 received = router.exchange(jEUR, EURS, 1e18, params);
        assertGt(received, 0);
    }

    function testExchange_SwapStableCoinsSamePool() public {
        // Setup
        address tokenIn = PAR;
        address tokenOut = EURS;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolJCAD,
            derivativeCAD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);
        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapStablecoinUsingJarvis_1() public {
        // Setup
        address tokenIn = EURS;
        address tokenOut = CADC;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolJCAD,
            derivativeCAD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);
        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapStablecoinUsingJarvis_2() public {
        // Setup
        address tokenIn = XSGD;
        address tokenOut = EURT;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeSGD,
            poolJeur,
            derivativeEUR
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);

        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapjTokenToStablecoin() public {
        // Setup
        address tokenIn = jEUR;
        address tokenOut = XSGD;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolSGD,
            derivativeSGD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);

        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapjToken() public {
        // Setup
        address tokenIn = jEUR;
        address tokenOut = jCAD;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolJCAD,
            derivativeCAD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);

        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapjToken_2() public {
        // Setup
        address tokenIn = jEUR;
        address tokenOut = jSGD;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolSGD,
            derivativeSGD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);

        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function testExchange_SwapStablecoinTojToken() public {
        // Setup
        address tokenIn = EURS;
        address tokenOut = jSGD;
        uint256 decimals = ERC20(tokenIn).decimals();
        uint256 amountIn = 1 * 10**decimals;

        JarvisPoolRouter.ExchangeParams memory params = JarvisPoolRouter.ExchangeParams(
            derivativeEUR,
            poolSGD,
            derivativeSGD
        );

        uint256 received = swap(tokenIn, tokenOut, amountIn, params);
        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertGt(received, 0);
        assertEq(received, balance);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        JarvisPoolRouter.ExchangeParams memory params
    ) private returns (uint256 received) {
        tip(tokenIn, address(this), amountIn);
        // Swap
        ERC20(tokenIn).safeApprove(address(router), amountIn);

        uint256 balance = ERC20(tokenOut).balanceOf(address(this));
        assertEq(balance, 0);

        received = router.exchange(tokenIn, tokenOut, amountIn, params);
    }
}
