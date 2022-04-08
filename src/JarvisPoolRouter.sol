// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ICurveExchange} from "src/interfaces/ICurveExchange.sol";
import {ERC20, SafeTransferLib} from "solfege/utils/SafeTransferLib.sol";
import {ISynthereumLiquidityPool, IDerivative} from "src/interfaces/Interfaces.sol";

contract JarvisPoolRouter {
    using SafeTransferLib for ERC20;

    struct ExchangeParams {
        // Derivative of source pool
        address derivative;
        // Destination pool
        address destPool;
        // Derivative of destination pool
        address destDerivative;
    }

    ICurveExchange public constant curve = ICurveExchange(0x04aAB3e45Aa6De7783D67FCfB21Bccf2401Ca31D);

    function exchange(
        address from,
        address to,
        uint256 amountIn,
        ExchangeParams calldata params
    ) external returns (uint256 received) {
        (address pool, uint256 minDy) = curve.get_best_rate(from, to, amountIn);
        ERC20(from).safeTransferFrom(msg.sender, address(this), amountIn);

        // Direct swap is possible
        if (pool != address(0)) {
            allow(ERC20(from), address(curve));
            received = curve.exchange(pool, from, to, amountIn, minDy, msg.sender);
        } else {
            require(params.derivative != address(0), "JarvisPoolRouter: Derivative not set");
            require(params.destPool != address(0), "JarvisPoolRouter: DestPool not set");
            require(params.destDerivative != address(0), "JarvisPoolRouter: DestDerivative not set");

            // jSynth
            address intermediary = IDerivative(params.derivative).tokenCurrency();
            address dest = IDerivative(params.destDerivative).tokenCurrency();

            if (from == intermediary) {
                received = redeemAndMint(params, amountIn);
            } else {
                (pool, minDy) = curve.get_best_rate(from, intermediary, amountIn);
                allow(ERC20(from), address(curve));
                received = curve.exchange(pool, from, intermediary, amountIn, minDy, address(this));
                received = redeemAndMint(params, received);
            }

            if (to == dest) {
                ERC20(dest).safeTransfer(msg.sender, received);
            } else {
                /// Swap jSynth to dest token.
                (pool, minDy) = curve.get_best_rate(dest, to, received);
                allow(ERC20(dest), address(curve));
                received = curve.exchange(pool, dest, to, received, minDy, msg.sender);
            }
        }
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

    /// @notice Approve if needed
    function allow(ERC20 token, address recipient) private {
        if (recipient == address(0)) return;
        if (token.allowance(address(this), address(recipient)) == 0) {
            token.safeApprove(address(recipient), type(uint256).max);
        }
    }
}
