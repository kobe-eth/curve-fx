// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ISynthereumLiquidityPool, IDerivative} from "src/interfaces/Interfaces.sol";
import {CurveExchange, CurvePoolHelper, Registry, LendingPool} from "src/interfaces/CurveInterfaces.sol";

/// @title CurveFxRouter
/// Version 0.0.1
contract CurveFxRouter {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    ////////////////////////////////////////////////////////////////
    /// ---  STRUCTS
    ///////////////////////////////////////////////////////////////

    /// @notice Synthereum Liquidity Pools parameters
    struct ExchangeParams {
        // Derivative of source pool
        address derivative;
        // Destination pool
        address destPool;
        // Derivative of destination pool
        address destDerivative;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CONSTANTS
    ///////////////////////////////////////////////////////////////

    /// @notice AAVE 107 Pool
    address public constant METAPOOL = address(0x447646e84498552e62eCF097Cc305eaBFFF09308);
    /// @notice Collateral
    address public constant COLLATERAL = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    /// @notice Exchange Contract (id=2 Address Provider)
    CurveExchange public constant CURVE = CurveExchange(0x04aAB3e45Aa6De7783D67FCfB21Bccf2401Ca31D);
    /// @notice Zap Contract Aave Metapools
    CurvePoolHelper public constant ZAP = CurvePoolHelper(0x5ab5C56B9db92Ba45a0B46a207286cD83C15C939);
    /// @notice V2 Market
    LendingPool public constant AAVE_LENDING_POOL = LendingPool(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);

    /// @notice Exchange tokens using Jarvis Liquidity pool on Curve and/or jSynth
    /// @param from Token the caller want to exchange.
    /// @param to Token desired.
    /// @param amountIn fromToken amount to exchange.
    /// @param slippageTolerence Slippage tolerated. 1e18 = 100%.
    /// @param params Params related to jSyng Liquidity pools used to mint/redeemAndMint jSynth tokens.
    function exchange(
        address from,
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        ExchangeParams calldata params
    ) external returns (uint256 received) {
        require(slippageTolerence <= 1e18, "SLIPPAGE_TO0_HIGH");
        // Transfer from caller
        ERC20(from).safeTransferFrom(msg.sender, address(this), amountIn);

        // First check to look if fromToken is in MAI+3Pool3CRV-f
        bool isInMetapool = isMeta(from);

        // Look for intermediary jSynth if needed.
        address intermediary = IDerivative(params.derivative).tokenCurrency();

        if (from == intermediary) {
            received = handleJarvisTokenSwap(from, to, amountIn, slippageTolerence, params);
        } else if (from == COLLATERAL) {
            received = handleCollateralSwap(to, amountIn, slippageTolerence, params);
        } else if (isInMetapool) {
            received = handleMetapoolSwap(from, to, amountIn, slippageTolerence, params);
        } else {
            received = handleJarvisPoolSwap(from, to, amountIn, slippageTolerence, params);
        }

        require(received > 0, "SWAP_FAILED");
        ERC20(to).safeTransfer(msg.sender, received);
    }

    ////////////////////////////////////////////////////////////////
    /// --- SWAP HELPERS
    ///////////////////////////////////////////////////////////////

    /// @notice Handle Exchange in case from token is jSynth.
    function handleJarvisTokenSwap(
        address from,
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (to == COLLATERAL) {
            received = redeemCollateral(from, params.derivative, amountIn);
        } else if (isInMetapool) {
            received = redeemCollateral(from, params.derivative, amountIn);
            received = exchangeToUnderlying(COLLATERAL, to, received, slippageTolerence, address(this));
        } else if (to == dest) {
            received = redeemAndMint(params, amountIn);
        } else {
            (address pool, uint256 minDy) = CURVE.get_best_rate(from, to, amountIn);
            if (pool != address(0)) {
                received = exchangeCoins(pool, from, to, amountIn, minDy, slippageTolerence, address(this));
            } else {
                received = redeemAndMint(params, amountIn);
                (pool, minDy) = CURVE.get_best_rate(dest, to, received);
                received = exchangeCoins(pool, dest, to, received, minDy, slippageTolerence, address(this));
            }
        }
    }

    /// @notice Handle Exchange in case from token is jSynth collateral = USDC.
    function handleCollateralSwap(
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (isInMetapool) {
            received = exchangeToUnderlying(COLLATERAL, to, amountIn, slippageTolerence, address(this));
        } else if (to == dest) {
            received = mintFromCollateral(params, amountIn);
        } else {
            received = mintFromCollateral(params, amountIn);
            (address pool, uint256 minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, slippageTolerence, address(this));
        }
    }

    /// @notice Handle Exchange in case from token is in MAI+3Pool3CRV-f.
    function handleMetapoolSwap(
        address from,
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (to == dest) {
            received = exchangeToUnderlying(from, COLLATERAL, amountIn, slippageTolerence, address(this));
            received = mintFromCollateral(params, received);
        } else if (isInMetapool) {
            received = exchangeToUnderlying(from, to, amountIn, slippageTolerence, address(this));
        } else {
            received = exchangeToUnderlying(from, COLLATERAL, amountIn, slippageTolerence, address(this));
            received = mintFromCollateral(params, received);
            (address pool, uint256 minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, slippageTolerence, address(this));
        }
    }

    /// @notice Handle Exchange in case from token is in Jarvis Curve Pools.
    function handleJarvisPoolSwap(
        address from,
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address intermediary = IDerivative(params.derivative).tokenCurrency();
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        (address pool, uint256 minDy) = CURVE.get_best_rate(from, to, amountIn);

        if (pool != address(0)) {
            received = exchangeCoins(pool, from, to, amountIn, minDy, slippageTolerence, address(this));
        } else if (to == COLLATERAL || isInMetapool) {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, slippageTolerence, address(this));
            received = redeemCollateral(intermediary, params.derivative, received);

            if (isInMetapool && to != COLLATERAL) {
                received = exchangeToUnderlying(COLLATERAL, to, received, slippageTolerence, address(this));
            }
        } else if (to == dest) {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, slippageTolerence, address(this));
            received = redeemAndMint(params, received);
        } else {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, slippageTolerence, address(this));
            received = redeemAndMint(params, received);
            (pool, minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, slippageTolerence, address(this));
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- CURVE HELPERS
    ///////////////////////////////////////////////////////////////

    function isMeta(address token) public view returns (bool) {
        address _registry = CURVE.factory_registry();
        token = getUnderlying(token);
        address[8] memory coins = Registry(_registry).get_underlying_coins(METAPOOL);
        uint256 length = coins.length;

        for (uint256 i; i < length; ++i) {
            if (token == coins[i]) {
                return true;
            }
        }
        return false;
    }

    function exchangeToUnderlying(
        address from,
        address to,
        uint256 amountIn,
        uint256 slippageTolerence,
        address receiver
    ) internal returns (uint256 received) {
        (int128 _from, int128 _to, uint256 dy) = getExchangeAmount(from, to, amountIn);
        allow(ERC20(from), address(ZAP));
        dy = dy.mulWadDown(1e18 - slippageTolerence);
        received = ZAP.exchange_underlying(METAPOOL, _from, _to, amountIn, dy, receiver);
    }

    function exchangeCoins(
        address pool,
        address from,
        address to,
        uint256 amountIn,
        uint256 minDy,
        uint256 slippageTolerence,
        address receiver
    ) internal returns (uint256 received) {
        allow(ERC20(from), address(CURVE));
        minDy = minDy.mulWadDown(1e18 - slippageTolerence);
        received = CURVE.exchange(pool, from, to, amountIn, 0, receiver);
    }

    function getExchangeAmount(
        address from,
        address to,
        uint256 amount
    )
        public
        view
        returns (
            int128,
            int128,
            uint256 dy
        )
    {
        // Metapools Registry
        address _registry = CURVE.factory_registry();
        // Look for aToken || or asset
        from = getUnderlying(from);
        // Look for aToken || or asset
        to = getUnderlying(to);

        (int128 _from, int128 _to, ) = Registry(_registry).get_coin_indices(METAPOOL, from, to);
        dy = CurvePoolHelper(METAPOOL).get_dy_underlying(_from, _to, amount);

        return (_from, _to, dy);
    }

    function getUnderlying(address asset) public view returns (address) {
        LendingPool.ReserveData memory reserveData = AAVE_LENDING_POOL.getReserveData(asset);
        if (reserveData.aTokenAddress != address(0)) {
            return reserveData.aTokenAddress;
        }
        return asset;
    }

    ////////////////////////////////////////////////////////////////
    /// --- JARVIS SYNTHEREUM HELPERS
    ///////////////////////////////////////////////////////////////

    function mintFromCollateral(ExchangeParams calldata params, uint256 received)
        private
        returns (uint256 destReceived)
    {
        address pool = IDerivative(params.destDerivative).getPoolMembers()[0];
        ISynthereumLiquidityPool.MintParams memory mintParams = ISynthereumLiquidityPool.MintParams(
            params.destDerivative,
            0,
            received,
            1e15,
            block.timestamp + 60,
            address(this)
        );

        allow(ERC20(COLLATERAL), pool);
        (destReceived, ) = ISynthereumLiquidityPool(pool).mint(mintParams);
    }

    function redeemCollateral(
        address token,
        address derivative,
        uint256 received
    ) private returns (uint256 destReceived) {
        address pool = IDerivative(derivative).getPoolMembers()[0];
        ISynthereumLiquidityPool.RedeemParams memory redeemParams = ISynthereumLiquidityPool.RedeemParams(
            derivative,
            received,
            0,
            1e15,
            block.timestamp + 60,
            address(this)
        );

        allow(ERC20(token), pool);
        (destReceived, ) = ISynthereumLiquidityPool(pool).redeem(redeemParams);
    }

    function redeemAndMint(ExchangeParams calldata params, uint256 received) private returns (uint256 destReceived) {
        address fromPool = IDerivative(params.derivative).getPoolMembers()[0];
        address from = IDerivative(params.derivative).tokenCurrency();

        ISynthereumLiquidityPool.ExchangeParams memory synthParams = ISynthereumLiquidityPool.ExchangeParams(
            params.derivative,
            params.destPool,
            params.destDerivative,
            received,
            0,
            1e15,
            block.timestamp + 60,
            address(this)
        );

        allow(ERC20(from), fromPool);
        (destReceived, ) = ISynthereumLiquidityPool(fromPool).exchange(synthParams);
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS
    ///////////////////////////////////////////////////////////////

    function allow(ERC20 token, address recipient) private {
        if (recipient == address(0)) return;
        if (token.allowance(address(this), address(recipient)) == 0) {
            token.safeApprove(address(recipient), type(uint256).max);
        }
    }
}
