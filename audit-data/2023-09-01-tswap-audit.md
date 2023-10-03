---
title: TSwap Audit Report
author: YOUR_NAME_HERE
date: September 1, 2023
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---
\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries TSwap Initial Audit Report\par}
    \vspace{1cm}
    {\Large Version 0.1\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

# TSwap Audit Report

Prepared by: YOUR_NAME_HERE
Lead Auditors: 

- [YOUR_NAME_HERE](enter your URL here)

Assisting Auditors:

- None

# Table of contents
<details>

<summary>See table</summary>

- [TSwap Audit Report](#tswap-audit-report)
- [Table of contents](#table-of-contents)
- [About YOUR\_NAME\_HERE](#about-your_name_here)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
- [Protocol Summary](#protocol-summary)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] `swapPoolTokenForWethBasedOnInputPoolToken` calculates `wethBought` backwards](#h-1-swappooltokenforwethbasedoninputpooltoken-calculates-wethbought-backwards)
    - [\[M-1\] Rebase, fee-on-transfer, and centralized ERC20s can break core invariant](#m-1-rebase-fee-on-transfer-and-centralized-erc20s-can-break-core-invariant)
</details>
</br>

# About YOUR_NAME_HERE

<!-- Tell people about you! -->

# Disclaimer

The YOUR_NAME_HERE team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

# Audit Details

**The findings described in this document correspond the following commit hash:**
```
026da6e73fde0dd0a650d623d0411547e3188909
```

## Scope 

```
#-- src
|   #-- PoolFactory.sol
|   #-- TSwapPool.sol
```

# Protocol Summary 

TSWAP is an constant-product AMM that allows users permissionlessly trade WETH and any other ERC20 token set during deployment. Users can trade without restrictions, just paying a tiny fee in each swapping operation. Fees are earned by liquidity providers, who can deposit and withdraw liquidity at any time.

## Roles

- Liquidity Provider: An account who deposits assets into the pool to earn trading fees. 
- User: An account who swaps tokens.

# Executive Summary

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 3                      |
| Medium   | 2                      |
| Low      | 2                      |
| Info     | 0                      |
| Gas      | 0                      |
| Total    | 5                      |

# Findings

## High 

### [H-1] The `sellPoolTokens` function miscalculates amount of tokens bought

The `sellPoolTokens` is intended to allow users easily sell pool tokens and receive WETH in exchange. Users indicate how many pool tokens they're willing to sell using the `poolTokenAmount` parameter. However, the function currently miscalculates the swapped amount.

This is due to the fact that the `swapExactOutput` function is called, whereas the `swapExactInput` is the one that should be called. Because users specify the exact amount of input tokens - not output tokens.

Consider changing the implementation to use the `swapExactInput` function. Note that this would also require to change the `sellPoolTokens` function to accept a new parameter (e.g., `minWethToReceive`) to be passed down to `swapExactInput`.

```diff
    function sellPoolTokens(
        uint256 poolTokenAmount
+       uint256 minWethToReceive
    ) external returns (uint256 wethAmount) {
-       return swapExactOutput(
+       return swapExactInput(
            i_poolToken,
            poolTokenAmount,
            WETH_TOKEN,
+           minWethToReceive,
            uint64(block.timestamp)
        );
    }
```

### [H-2] Protocol may take too many tokens from users during swap

A flaw in `getInputAmountBasedOnOutput`, where 10000 should be 1000. This miscalulates amount of tokens to be deposited by user. Combined with the lack of slippage protection, this would put users at risk of having their funds taken by liquidity providers.

### [H-3] Lack of slippage protection in `swapExactOutput` function

Does not include nor check a `maxInputAmount` parameter.

## Medium

### [M-1] Rebase, fee-on-transfer, and centralized ERC20s can break core invariant 

### [M-2] Missing deadline check when adding liquidity

The `deposit` function accepts a `deadline` parameter, which according to documentation is "The deadline for the transaction to be completed by". However, this parameter is never used. As a consequence, operations that add liquidity to the pool might be executed at unexpected times, in market conditions where the deposit rate is unfavorable for the caller.

Consider making the following change to the `deposit` function:

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
        revertIfZero(wethToDeposit)
+       revertIfDeadlinePassed(deadline)
        returns (uint256 liquidityTokensToMint)
    {
```

## Low

### [L-1] Wrong values logged in `LiquidityAdded` event

When the `LiquidityAdded` event is emitted in the `_addLiquidityMintAndTransfer` function, it logs values in an incorrect order. The `poolTokensToDeposit` value should go in the third place, whereas the `wethToDeposit` value should go second.

```diff
- emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+ emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);
```

### [L-2] Swapping function returns default value

The `swapExactInput` function is expected to return the actual amount of tokens bought by the caller. However, while it declares the named return value `output`, it never assigns a value to it, nor uses an explicit `return` statement.

As a result, the function will always return zero. Consider modifying the function so that it always return the correct amount of tokens bought by the caller.

