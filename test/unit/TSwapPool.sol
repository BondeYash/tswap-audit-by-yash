// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock tokenA;
    ERC20Mock weth;

    address liquidityProvider = address(1);
    address user = address(2);

    function setUp() public {
        tokenA = new ERC20Mock();
        pool = new TSwapPool(address(tokenA), "LTokenA", "LA");

        // Overright the WETH address
        deployCodeTo("ERC20Mock.sol:ERC20Mock", address(pool.WETH_TOKEN()));
        weth = ERC20Mock(address(pool.WETH_TOKEN()));

        weth.mint(liquidityProvider, 200e18);
        tokenA.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        tokenA.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        tokenA.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, block.timestamp);

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(tokenA.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(tokenA.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        tokenA.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, block.timestamp);
        vm.stopPrank();

        vm.startPrank(user);
        tokenA.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapPoolTokenForWethBasedOnInputPoolToken(10e18, expected, block.timestamp);
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        tokenA.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, block.timestamp);

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, block.timestamp);

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(tokenA.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        tokenA.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, block.timestamp);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        tokenA.approve(address(pool), 10e18);
        pool.swapPoolTokenForWethBasedOnInputPoolToken(10e18, expected, block.timestamp);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, block.timestamp);
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + tokenA.balanceOf(liquidityProvider) > 400e18);
    }
}
