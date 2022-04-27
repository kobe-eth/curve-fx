// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {ISynthereumLiquidityPool, IDerivative} from "src/interfaces/Interfaces.sol";
import {CurveExchange, CurvePool, Registry, LendingPool} from "src/interfaces/CurveInterfaces.sol";

/// @title CurveFxRouter
contract CurveFxRouter {
    using SafeTransferLib for ERC20;

    ////////////////////////////////////////////////////////////////
    /// ---  STRUCTS
    ///////////////////////////////////////////////////////////////

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

    /// @notice Zap Contract Aave Metapools
    CurvePool public constant ZAP = CurvePool(0x5ab5C56B9db92Ba45a0B46a207286cD83C15C939);
    /// @notice Exchange Contract (id=2 Address Provider)
    CurveExchange public constant CURVE = CurveExchange(0x04aAB3e45Aa6De7783D67FCfB21Bccf2401Ca31D);
    /// @notice V2 Market
    LendingPool public constant AAVE_LENDING_POOL = LendingPool(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);

    function exchange(
        address from,
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) external returns (uint256 received) {
        // Transfer from caller
        ERC20(from).safeTransferFrom(msg.sender, address(this), amountIn);

        bool isInMetapool = isMeta(from);
        address intermediary = IDerivative(params.derivative).tokenCurrency();

        if (from == intermediary) {
            received = handleJarvisTokenSwap(from, to, amountIn, params);
        } else if (from == COLLATERAL) {
            received = handleCollateralSwap(to, amountIn, params);
        } else if (isInMetapool) {
            received = handleMetapoolSwap(from, to, amountIn, params);
        } else {
            received = handleJarvisPoolSwap(from, to, amountIn, params);
        }

        require(received > 0, "SWAP_FAILED");
        ERC20(to).safeTransfer(msg.sender, received);
    }

    ////////////////////////////////////////////////////////////////
    /// --- SWAP HELPERS
    ///////////////////////////////////////////////////////////////

    function handleJarvisTokenSwap(
        address from,
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (to == COLLATERAL) {
            received = redeemCollateral(from, params.derivative, amountIn);
        } else if (isInMetapool) {
            received = redeemCollateral(from, params.derivative, amountIn);
            received = exchangeToUnderlying(COLLATERAL, to, received, address(this));
        } else if (to == dest) {
            received = redeemAndMint(params, amountIn);
        } else {
            (address pool, uint256 minDy) = CURVE.get_best_rate(from, to, amountIn);
            if (pool != address(0)) {
                received = exchangeCoins(pool, from, to, amountIn, minDy, address(this));
            } else {
                received = redeemAndMint(params, amountIn);
                (pool, minDy) = CURVE.get_best_rate(dest, to, received);
                received = exchangeCoins(pool, dest, to, received, minDy, address(this));
            }
        }
    }

    function handleCollateralSwap(
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (isInMetapool) {
            received = exchangeToUnderlying(COLLATERAL, to, amountIn, address(this));
        } else if (to == dest) {
            received = mintFromCollateral(params, amountIn);
        } else {
            received = mintFromCollateral(params, amountIn);
            (address pool, uint256 minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, address(this));
        }
    }

    function handleMetapoolSwap(
        address from,
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        if (to == dest) {
            received = exchangeToUnderlying(from, COLLATERAL, amountIn, address(this));
            received = mintFromCollateral(params, received);
        } else if (isInMetapool) {
            received = exchangeToUnderlying(from, to, amountIn, address(this));
        } else {
            received = exchangeToUnderlying(from, COLLATERAL, amountIn, address(this));
            received = mintFromCollateral(params, received);
            (address pool, uint256 minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, address(this));
        }
    }

    function handleJarvisPoolSwap(
        address from,
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) internal returns (uint256 received) {
        bool isInMetapool = isMeta(to);
        address intermediary = IDerivative(params.derivative).tokenCurrency();
        address dest = IDerivative(params.destDerivative).tokenCurrency();

        (address pool, uint256 minDy) = CURVE.get_best_rate(from, to, amountIn);

        if (pool != address(0)) {
            received = exchangeCoins(pool, from, to, amountIn, minDy, address(this));
        } else if (to == COLLATERAL || isInMetapool) {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, address(this));
            received = redeemCollateral(intermediary, params.derivative, received);

            if (isInMetapool && to != COLLATERAL) {
                received = exchangeToUnderlying(COLLATERAL, to, received, address(this));
            }
        } else if (to == dest) {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, address(this));
            received = redeemAndMint(params, received);
        } else {
            (pool, minDy) = CURVE.get_best_rate(from, intermediary, amountIn);
            received = exchangeCoins(pool, from, intermediary, amountIn, minDy, address(this));
            received = redeemAndMint(params, received);
            (pool, minDy) = CURVE.get_best_rate(dest, to, received);
            received = exchangeCoins(pool, dest, to, received, minDy, address(this));
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
        address receiver
    ) internal returns (uint256 received) {
        (int128 _from, int128 _to, uint256 dy) = getExchangeAmount(from, to, amountIn);
        allow(ERC20(from), address(ZAP));
        received = ZAP.exchange_underlying(METAPOOL, _from, _to, amountIn, 0, receiver);
    }

    function exchangeCoins(
        address pool,
        address from,
        address to,
        uint256 amountIn,
        uint256 minDy,
        address receiver
    ) internal returns (uint256 received) {
        allow(ERC20(from), address(CURVE));
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
        dy = CurvePool(METAPOOL).get_dy_underlying(_from, _to, amount);

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

    /// @notice Approve if needed
    function allow(ERC20 token, address recipient) private {
        if (recipient == address(0)) return;
        if (token.allowance(address(this), address(recipient)) == 0) {
            token.safeApprove(address(recipient), type(uint256).max);
        }
    }
}
