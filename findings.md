
### Highs

### [H-1] The `TSwapPool:deposit` function has an unused parameter `deadline` which reverts the transaction### 

**Description:** The `TSwapPool::deposit` function has one parameter called deadline which accroding to 
the documenatation is "The deadline for the transaction to be completed by"", However this parameter is never
used As a consequence the functions which adds liquidity might get executed unexpected time , in market condition
where market is not o favorable
 

**Impact:** Transaction could get executed even at the market unfavorable situation.
Even after giving deadline parameter

**Proof of Concept:** The `TSwapPool::deposit` has unused parameter called deposit

**Recommended Mitigation:** Try to add the revert error in the function `TSwapPool::deposit`
try to make use of deadline parameter

```diff
function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
+       revertIfDeadlinePassed(deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
    {}
```

### [H-2] The `TSwapPool:getInputAmountBasedOnOutput` charges way too much fees to user 
###
**Description:** The `getInputAmountBasedOnOutput` function is intended to calculate amount of tokens
a user should deposit given an amount of token of output tokens. However, the function currently miscalculate
the resulting amount. When calculating the fees it scales down to 10_000 instead of 1000 

**Impact:** Protocol takes more fees than expected by user

**Proof of Concept:**

**Recommended Mitigation:**
``` diff 
   function getInputAmountBasedOnOutput(
        uint256 outputAmount,
        uint256 inputReserves,
        uint256 outputReserves
    )
        public
        pure
        revertIfZero(outputAmount)
        revertIfZero(outputReserves)
        returns (uint256 inputAmount)
    {
       
-     return ((inputReserves * outputAmount) * 10_000) / ((outputReserves - outputAmount) * 997);
-     return ((inputReserves * outputAmount) * 1_000) / ((outputReserves - outputAmount) * 997);
+     
    }
```
### [H-3] No Slippage Protection in `TSwapPool::swapExactOutput()` function causes user to recieve potentially way fever tokens ### 

**Description:** The `swapExactOutput` does not support any kind of slippage protection .
This function is similar as `TSwapPool::swapExcatInput` function which specifies a `minOutputAmount`
similar to that `TSwapPool::swapExactOutput` should also specify `maxInputAmount`


**Impact:** If the market condition changes before the trabsaction occurs user could get a much worse swap 

**Proof of Concept:**
1. The price of 1 WETH right now is 1,000 USDC
2. User inputs a `swapExactOutput` looking for 1 WETH
   1. inputToken = USDC
   2. outputToken = WETH
   3. outputAmount = 1
   4. deadline = whatever
3. The function does not offer a maxInput amount
4. As the transaction is pending in the mempool, the market changes! And the price moves HUGE -> 1 WETH is now 10,000 USDC. 10x more than the user expected
5. The transaction completes, but the user sent the protocol 10,000 USDC instead of the expected 1,000 USDC

**Recommended Mitigation:** We should include a `maxInputAmount` so the user only has to spend up to a specific amount, and can predict how much they will spend on the protocol. 

```diff
    function swapExactOutput(
        IERC20 inputToken, 
+       uint256 maxInputAmount,
.
.
.
        inputAmount = getInputAmountBasedOnOutput(outputAmount, inputReserves, outputReserves);
+       if(inputAmount > maxInputAmount){
+           revert();
+       }        
        _swap(inputToken, inputAmount, outputToken, outputAmount);
```

### [H-4] `TSwapPool::sellPoolTokens` mismatches input and output tokens causing users to receive the incorrect amount of tokens

**Description:** The `sellPoolTokens` function is intended to allow users to easily sell pool tokens and receive WETH in exchange. Users indicate how many pool tokens they're willing to sell in the `poolTokenAmount` parameter. However, the function currently miscalculaes the swapped amount. 

This is due to the fact that the `swapExactOutput` function is called, whereas the `swapExactInput` function is the one that should be called. Because users specify the exact amount of input tokens, not output. 

**Impact:** Users will swap the wrong amount of tokens, which is a severe disruption of protcol functionality. 

**Proof of Concept:** 
<write PoC here>

**Recommended Mitigation:** 

Consider changing the implementation to use `swapExactInput` instead of `swapExactOutput`. Note that this would also require changing the `sellPoolTokens` function to accept a new parameter (ie `minWethToReceive` to be passed to `swapExactInput`)

```diff
    function sellPoolTokens(
        uint256 poolTokenAmount,
+       uint256 minWethToReceive,    
        ) external returns (uint256 wethAmount) {
-        return swapExactOutput(i_poolToken, i_wethToken, poolTokenAmount, uint64(block.timestamp));
+        return swapExactInput(i_poolToken, poolTokenAmount, i_wethToken, minWethToReceive, uint64(block.timestamp));
    }
```

Additionally, it might be wise to add a deadline to the function, as there is currently no deadline. (MEV later)

### [H-5] In `TSwapPool::_swap` the extra tokens given to users after every `swapCount` breaks the protocol invariant of `x * y = k`

**Description:** The protocol follows a strict invariant of `x * y = k`. Where:
- `x`: The balance of the pool token
- `y`: The balance of WETH
- `k`: The constant product of the two balances

This means, that whenever the balances change in the protocol, the ratio between the two amounts should remain constant, hence the `k`. However, this is broken due to the extra incentive in the `_swap` function. Meaning that over time the protocol funds will be drained. 

The follow block of code is responsible for the issue. 

```javascript
        swap_count++;
        if (swap_count >= SWAP_COUNT_MAX) {
            swap_count = 0;
            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
        }
```

**Impact:** A user could maliciously drain the protocol of funds by doing a lot of swaps and collecting the extra incentive given out by the protocol. 

Most simply put, the protocol's core invariant is broken. 

**Proof of Concept:** 
1. A user swaps 10 times, and collects the extra incentive of `1_000_000_000_000_000_000` tokens
2. That user continues to swap untill all the protocol funds are drained

<details>
<summary>Proof Of Code</summary>

Place the following into `TSwapPool.t.sol`.

```javascript

    function testInvariantBroken() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 outputWeth = 1e17;

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        poolToken.mint(user, 100e18);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));

        int256 startingY = int256(weth.balanceOf(address(pool)));
        int256 expectedDeltaY = int256(-1) * int256(outputWeth);

        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(pool));
        int256 actualDeltaY = int256(endingY) - int256(startingY);
        assertEq(actualDeltaY, expectedDeltaY);
    }
```

</details>

**Recommended Mitigation:** Remove the extra incentive mechanism. If you want to keep this in, we should account for the change in the x * y = k protocol invariant. Or, we should set aside tokens in the same way we do with fees. 

```diff
-        swap_count++;
-        // Fee-on-transfer
-        if (swap_count >= SWAP_COUNT_MAX) {
-            swap_count = 0;
-            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
-        }
```



### Informationals

### [I-1] The error `PoolFactory::PoolFactory__PoolDoesNotExist()` never used in program### 

```diff
-  error PoolFactory__PoolDoesNotExist(address tokenAddress);
```

### [I-2] The `PoolFactory::createPool` uses name() function to set symbol instead of using `symbol()` function

```diff
-  string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+  string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```

### [I-3] The `PoolFactory::constructor()` lacks the zero address checks 

```diff
     constructor(address wethToken) {
+        if (wethToken == address(0)) {
+            revert();
+        }
        i_wethToken = wethToken;
    }

```

### [I-4]: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

- Found in src/TSwapPool.sol [Line: 44](src/TSwapPool.sol#L44)

	```solidity
	    event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
	```

- Found in src/TSwapPool.sol [Line: 45](src/TSwapPool.sol#L45)

	```solidity
	    event LiquidityRemoved(address indexed liquidityProvider, uint256 wethWithdrawn, uint256 poolTokensWithdrawn);
	```

### Lows 

### [L-1] The `TSwapPool::LiquidityAdded` event has parameters out of order causing event to emit wrong info ###

**Description:** When the `TSwapPool::Liquidity` added event is emmited in the 
`TSwapPool::_addLiquidityMintAndTransfer()` function, it logs value in incorrect order
The `poolTokenstoDeposit` should go on third position and the `wethToDeposit` in second position


**Impact:** Event emission is incorrect , leads to off chain function potentially malfunctions


**Recommended Mitigation:** 
````diff
-  emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+  emit LiquidityAdded(msg.sender, wethToDeposit , poolTokensToDeposit);


```
