// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract TSwapPoolHandler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    int256 public deltaX;

    address liquidityProvider = address(123);
    uint256 DEFAULT_LIQUIDITY_AMOUNT = 10e18;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(address(pool.getWeth()));
        poolToken = ERC20Mock(address(pool.getPoolToken()));
    }

    // get all methods with
    // forge inspect TSwapPool methods

    // We should have the lower bound be 1
    // upper bound not be too high

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 wethAmount) public {
        int256 startingPoolTokenBalance = int256(poolToken.balanceOf(address(pool)));
        int256 startingWethBalance = int256(weth.balanceOf(address(pool)));

        if (weth.balanceOf(address(pool)) <= pool.getMinimumWethDepositAmount()) {
            return;
        }

        wethAmount = bound(wethAmount, pool.getMinimumWethDepositAmount(), weth.balanceOf(address(pool)));
        uint64 deadline = uint64(block.timestamp);
        uint256 poolTokenAmount =
            pool.getInputAmountBasedOnOutput(wethAmount, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool)));
        if (poolToken.balanceOf(address(this)) < poolTokenAmount) {
            poolToken.mint(address(this), poolTokenAmount - poolToken.balanceOf(address(this)) + 1);
        }
        poolToken.approve(address(pool), type(uint256).max);

        pool.swapExactOutput({
            inputToken: poolToken,
            maxInputAmount: type(uint256).max,
            outputToken: weth,
            outputAmount: wethAmount,
            deadline: deadline
        });

        uint256 endingPoolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 endingWethBalance = weth.balanceOf(address(pool));

        // sell tokens == x == poolTokens
        int256 deltaPoolToken = int256(endingPoolTokenBalance) - int256(startingPoolTokenBalance);
        int256 deltaWeth = int256(endingWethBalance) - int256(startingWethBalance);
        int256 one = int256(1000);
        int256 fee = int256(3);
        int256 calculatedDeltaPoolToken = (deltaWeth / startingWethBalance) / (one - (deltaWeth / startingWethBalance))
            * (one / (one - fee)) * startingPoolTokenBalance;
        deltaX = calculatedDeltaPoolToken - deltaPoolToken; // should be 0
    }

    function deposit(uint256 liquidityAmount) public {
        liquidityAmount = bound(liquidityAmount, pool.getMinimumWethDepositAmount(), type(uint64).max);

        vm.startPrank(liquidityProvider);
        if (type(uint64).max < weth.balanceOf(liquidityProvider)) {
            return;
        }
        if (type(uint64).max < poolToken.balanceOf(liquidityProvider)) {
            return;
        }
        uint256 wethTopUpAmount = type(uint64).max - weth.balanceOf(liquidityProvider);
        uint256 tokenTopUpAmount = type(uint64).max - poolToken.balanceOf(liquidityProvider);

        weth.mint(liquidityProvider, wethTopUpAmount);
        poolToken.mint(liquidityProvider, tokenTopUpAmount);

        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(liquidityAmount, 0, type(uint64).max, uint64(block.timestamp));
        vm.stopPrank();
    }
}
