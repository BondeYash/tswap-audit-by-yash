// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, StdInvariant, console } from "forge-std/Test.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { TSwapPoolHandler } from "./TSwapPoolHandler.sol";

contract Invariant is StdInvariant, Test {
    PoolFactory factory;
    TSwapPool pool;
    ERC20Mock tokenA;
    ERC20Mock WETH;
    ERC20Mock tokenB;

    uint256 constant STARTING_X = 100e18; // starting ERC20
    uint256 constant STARTING_Y = 50e18; // starting WETH
    uint256 constant FEE = 997; // 997 / 1000
    uint256 constant FEE_PRECISION = 1000;

    TSwapPoolHandler handler;

    function setUp() public {
        factory = new PoolFactory();
        tokenA = new ERC20Mock();
        pool = TSwapPool(factory.createPool(address(tokenA)));

        // Overright the WETH address
        deployCodeTo("ERC20Mock.sol:ERC20Mock", address(pool.WETH_TOKEN()));

        // Create the initial x & y values for the pool
        tokenA.mint(address(this), STARTING_X);
        ERC20Mock(address(pool.WETH_TOKEN())).mint(address(this), STARTING_Y);
        pool.deposit(STARTING_Y, STARTING_Y, STARTING_X, uint64(block.timestamp));

        handler = new TSwapPoolHandler(pool);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = TSwapPoolHandler.deposit.selector;
        selectors[1] = TSwapPoolHandler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    // Normal Invariant
    // x * y = (x + ∆x) * (y − ∆y)
    // x = Token Balance X
    // y = Token Balance Y
    // ∆x = Change of token balance X
    // ∆y = Change of token balance Y
    // β = (∆y / y)
    // α = (∆x / x)

    // Final invariant equation without fees:
    // ∆x = (β/(1-β)) * x
    // ∆y = (α/(1+α)) * y

    // Invariant with fees
    // ρ = fee (between 0 & 1, aka a percentage)
    // γ = (1 - p) (pronounced gamma)
    // ∆x = (β/(1-β)) * (1/γ) * x
    // ∆y = (αγ/1+αγ) * y
    function invariant_testConstantProduct() public {
        uint256 gamma = FEE_PRECISION - FEE; // this is static

        uint256 x = tokenA.balanceOf(address(pool));
        uint256 y = ERC20Mock(address(pool.WETH_TOKEN())).balanceOf(address(pool));
        int256 actualAlpha = handler.deltaX() / int256(x);
        int256 actualBeta = handler.deltaY() / int256(y);

        int256 expectedDeltaX = (actualBeta / (1 - actualBeta)) * (1 / gamma) * int256(x);

        assertEq(handler.actualDeltaX(), expectedDeltaX);
    }
}
