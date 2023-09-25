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
#-- interfaces
|   #-- IFlashLoanReceiver.sol
|   #-- IPoolFactory.sol
|   #-- ITSwapPool.sol
|   #-- IThunderLoan.sol
#-- protocol
|   #-- AssetToken.sol
|   #-- OracleUpgradeable.sol
|   #-- ThunderLoan.sol
#-- upgradedProtocol
    #-- ThunderLoanUpgraded.sol
```

# Protocol Summary 

Puppy Rafle is a protocol dedicated to raffling off puppy NFTs with variying rarities. A portion of entrance fees go to the winner, and a fee is taken by another address decided by the protocol owner. 

## Roles

- Owner: The owner of the protocol who has the power to upgrade the implementation. 
- Liquidity Provider: A user who deposits assets into the protocol to earn interest. 
- User: A user who takes out flash loans from the protocol.

# Executive Summary

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 2                      |
| Medium   | 2                      |
| Low      | 3                      |
| Info     | 1                      |
| Gas      | 2                      |
| Total    | 10                     |

# Findings

## High 

### [H-1] `swapPoolTokenForWethBasedOnInputPoolToken` calculates `wethBought` backwards 

```diff
    function swapPoolTokenForWethBasedOnInputPoolToken(
        uint256 poolTokenAmount,
        uint256 minWeth,
        uint256 deadline
    )
        external
        revertIfDeadlinePassed(deadline)
        revertIfZero(poolTokenAmount)
        revertIfZero(minWeth)
        returns (uint256 wethBought)
    {
-       wethBought = getInputAmountBasedOnOutput(
-           poolTokenAmount, i_poolToken.balanceOf(address(this)), WETH_TOKEN.balanceOf(address(this))
-       );
+       wethBought = getOutputAmountBasedOnInput(
+           poolTokenAmount, i_poolToken.balanceOf(address(this)), WETH_TOKEN.balanceOf(address(this))
+       );
        if (wethBought < minWeth) {
            revert TSwapPool__WethToReceiveTooLow(wethBought);
        }
        _swapPoolTokensForWeth(poolTokenAmount, wethBought);
    }
```

### [M-1] Rebase, fee-on-transfer, and centralized ERC20s can break core invariant 

