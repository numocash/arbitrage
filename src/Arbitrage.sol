// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "./interfaces/IUniswapV2Callee.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";

import { NumoenLibrary } from "numoen-manager/libraries/NumoenLibrary.sol";
import { LendgineAddress } from "numoen-manager/libraries/LendgineAddress.sol";
import { IPair } from "numoen-core/interfaces/IPair.sol";

contract Arbitrage is IUniswapV2Callee {
    address private immutable factory;

    address private immutable uniFactory;

    constructor(address _factory, address _uniFactory) {
        factory = _factory;
        uniFactory = _uniFactory;
    }

    /*//////////////////////////////////////////////////////////////
                                ARB LOGIC
    //////////////////////////////////////////////////////////////*/

    struct ArbParams {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
        uint256 arbAmount;
        address recipient;
    }

    function arb0(ArbParams calldata params) external {
        address uniPair = IUniswapV2Factory(uniFactory).getPair(params.base, params.speculative);

        address pair = LendgineAddress.computePairAddress(
            factory,
            params.base,
            params.speculative,
            params.baseScaleFactor,
            params.speculativeScaleFactor,
            params.upperBound
        );

        IUniswapV2Pair(uniPair).swap(
            params.base < params.speculative ? 0 : params.arbAmount,
            params.base < params.speculative ? params.arbAmount : 0,
            address(this),
            abi.encode(
                UniCallbackData({
                    base: params.base,
                    speculative: params.speculative,
                    upperBound: params.upperBound,
                    pair: pair,
                    recipient: params.recipient
                })
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK LOGIC
    //////////////////////////////////////////////////////////////*/

    struct UniCallbackData {
        address base;
        address speculative;
        uint256 upperBound;
        address pair;
        address recipient;
    }

    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        UniCallbackData memory decoded = abi.decode(data, (UniCallbackData));

        // Determine output of Numoen swap
        uint256 speculativeBal = IERC20(decoded.speculative).balanceOf(decoded.pair);
        uint256 liquidity = IPair(decoded.pair).totalSupply();

        uint256 specAmount = amount0 > 0 ? amount0 : amount1;
        uint256 baseAmountOut = NumoenLibrary.getBaseOut(specAmount, speculativeBal, liquidity, decoded.upperBound);

        // Determine input of Uniswap swap
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(msg.sender).getReserves();
        uint256 numerator = (decoded.base < decoded.speculative ? r0 : r1) * specAmount * 1000;
        uint256 denominator = ((decoded.base < decoded.speculative ? r1 : r0) - specAmount) * 997;
        uint256 baseAmountIn = (numerator / denominator) + 1;

        // Swap on Numoen
        SafeTransferLib.safeTransfer(decoded.speculative, decoded.pair, specAmount);
        IPair(decoded.pair).swap(address(this), baseAmountOut, 0);

        // Payback Uniswap
        SafeTransferLib.safeTransfer(decoded.base, msg.sender, baseAmountIn);

        // Keep the difference
        SafeTransferLib.safeTransfer(decoded.base, decoded.recipient, baseAmountOut - baseAmountIn);
    }
}
