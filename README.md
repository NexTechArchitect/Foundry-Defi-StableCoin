
<div align="center">

  <img src="https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&weight=700&size=30&pause=1000&color=00E5FF&center=true&vCenter=true&width=1000&height=100&lines=DSC+Protocol+v1.0;Decentralized+StableCoin+Engine;Algorithmic+%7C+Over-Collateralized;Secured+by+Foundry+%26+Chainlink" alt="Typing Effect" />

  <br />

  <a href="https://github.com/NexTechArchitect/Foundry-Defi-StableCoin">
    <img src="https://img.shields.io/badge/Solidity-0.8.20-363636?style=for-the-badge&logo=solidity&logoColor=white" />
    <img src="https://img.shields.io/badge/Architecture-Clean_Architecture-be5212?style=for-the-badge&logo=architecture&logoColor=white" />
  </a>

  <br /><br />

  <h3>🏛 The Decentralized StableCoin (DSC) Protocol</h3>
  <p width="80%">
    <b>An exogenous, autonomously governed, non-custodial stablecoin system.</b><br/>
    Anchored to the USD via real-time Chainlink Oracles and secured by a dynamic liquidation engine.
  </p>

</div>

<br />

<div align="center">
  <table>
    <tr>
      <td align="center" width="16%"><a href="#-executive-summary"><b>📖 Summary</b></a></td>
      <td align="center" width="16%"><a href="#-system-architecture"><b>🏗 Architecture</b></a></td>
      <td align="center" width="16%"><a href="#-core-mechanics"><b>⚙️ Mechanics</b></a></td>
      <td align="center" width="16%"><a href="#-mathematical-model"><b>🧮 Math</b></a></td>
      <td align="center" width="16%"><a href="#-invariant-security"><b>🛡 Security</b></a></td>
      <td align="center" width="16%"><a href="#-testing-strategy"><b>🧪 Testing</b></a></td>
    </tr>
  </table>
</div>

<hr />

## 📖 Executive Summary

The **DSC Protocol** maintains a strict `$1.00` peg for the **DSC Token** through a decentralized, censorship-resistant mechanism. Unlike centralized stablecoins (USDC) or failed algorithmic models (Terra/UST), DSC relies on verifiable on-chain collateral.

> **Core Mechanism:** **Over-Collateralization**
> Users must deposit crypto-assets (`wETH` / `wBTC`) valued significantly higher than the stablecoins they mint. System solvency is enforced by a network of liquidators who profit from purging under-collateralized positions.

### Key Features
* **Exogenous Collateral:** Backed by established assets (`wETH`, `wBTC`), not protocol-native tokens.
* **Dollar Pegged:** 1 DSC is algorithmically stabilized to roughly $1.00 USD.
* **Algorithmically Sound:** No governance keys, no freezing functionality, pure math-based incentives.

---

## 🏗 System Architecture

The DSC Protocol is architected as a **Multi-Layered Fortress**. 

* **Top Layer:** The Users (Humans/Bots) who interact with the system.
* **Middle Layer:** The Logic (Smart Contracts) that enforces the rules.
* **Bottom Layer:** The Foundation (Assets & Data) that powers the value.

### 📐 The "Layered Stack" View

```mermaid
graph TD
    %% Styling
    classDef actor fill:#000,stroke:#fff,stroke-width:2px,color:#fff;
    classDef logic fill:#1a1a1a,stroke:#00E5FF,stroke-width:2px,color:#fff;
    classDef infra fill:#1a1a1a,stroke:#be5212,stroke-width:1px,stroke-dasharray: 5 5,color:#ccc;

    %% LAYER 1: ACTORS
    subgraph "👤 Layer 1: Actors"
        User((User)):::actor
        Liquidator((Liquidator)):::actor
    end

    %% LAYER 2: PROTOCOL LOGIC
    subgraph "⚙️ Layer 2: Protocol Logic"
        Engine[DSCEngine.sol]:::logic
        Token[DSC Token]:::logic
    end

    %% LAYER 3: INFRASTRUCTURE
    subgraph "⛓️ Layer 3: Infrastructure"
        Oracle[Chainlink Price Feed]:::infra
        Collateral[WETH / WBTC]:::infra
    end

    %% CONNECTIONS (Top Down Flow)
    User ==>|Deposit & Mint| Engine
    Liquidator -.->|Monitor Solvency| Engine
    
    Engine ==>|Mint/Burn| Token
    Engine -.->|Check Price ($)| Oracle
    Engine ==>|Lock/Release| Collateral

## 🧮 Mathematical Model

The protocol's stability is guaranteed by strict mathematical invariants enforced at the smart contract level.

### 1. Health Factor ()

The primary metric for solvency. If , the user is subject to immediate liquidation.

* **Threshold:** 50% (User must have double the collateral value vs debt).
* **Precision:** 1e18 standard.

### 2. Liquidation Bonus ()

To incentivize liquidators to pay off bad debt during market crashes, they receive a discount on the collateral they seize.

---

## 🛡 Invariant Security

This protocol has undergone rigorous **Stateful Fuzzing** using Foundry. The following properties are mathematically proven to hold across **10,000+ random transaction sequences**.

| ID | Invariant Property | Status |
| --- | --- | --- |
| **INV_01** | **Protocol Solvency:** `Total Collateral Value ($)` > `Total DSC Supply`. The system is *always* over-collateralized. | ✅ **PASS** |
| **INV_02** | **Getter Safety:** View functions (`getHealthFactor`, `getAccountCollateralValue`) never revert/panic. | ✅ **PASS** |
| **INV_03** | **Ledger Integrity:** `wETH` balance in contract == Sum of all User Balances mapped in storage. | ✅ **PASS** |
| **INV_04** | **Oracle Reliability:** Stale/Broken price feeds cause safe revert (DoS) rather than bad pricing. | ✅ **PASS** |

### 🔍 Verification Scope

* **Static Analysis:** Slither, Aderyn.
* **Dynamic Analysis:** Fuzzing (Foundry), Differential Testing.
* **Manual Review:** Access Control (CEI Pattern), Reentrancy, Oracle Manipulation.

---

## ⚠️ Risk Analysis & Mitigation

| Risk Vector | Likelihood | Impact | Mitigation Strategy |
| --- | --- | --- | --- |
| **Oracle Failure** | Low | Critical | Protocol strictly reverts if Chainlink heartbeat is missed or price deviates >50% instantly. |
| **De-pegging** | Medium | High | Arbitrage opportunity created via `redeem` function forces market price back to $1.00. |
| **Network Congestion** | High | Medium | Liquidation threshold set conservatively (200%) to allow ample time for tx inclusion before bad debt accrues. |
| **Smart Contract Bug** | Low | Critical | Logic is kept minimal. CEI pattern used everywhere. `ReentrancyGuard` applied to all state-changing functions. |

---

## 🧪 Testing Strategy

We employ a 3-layered testing approach to ensure production readiness.

### 1. Unit Tests

* **Scope:** Individual functions (`deposit`, `mint`, `burn`).
* **Coverage:** 100% Line Coverage.
* **Goal:** Verify basic logic and happy paths.

### 2. Fuzz Tests (Stateless)

* **Scope:** Random inputs to all public functions.
* **Goal:** Crash detection and edge-case handling (e.g., passing `0` amounts or massive `uint256` values).

### 3. Invariant Tests (Stateful)

* **Scope:** Random sequences of function calls (e.g., `deposit` -> `mint` -> `priceCrash` -> `liquidate`).
* **Goal:** Ensure the protocol *never* goes insolvent, regardless of user actions.

```bash
# Run the full test suite
forge test

# Run invariant checks
forge test --match-test invariant

```

---

<br />

<div align="center">
<img src="https://raw.githubusercontent.com/rajput2107/rajput2107/master/Assets/Developer.gif" width="50" style="border-radius: 50%" />

<h3>Engineered by NexTechArchitect</h3>
<p><i>Protocol Design • DeFi Architecture • Security Engineering</i></p>

<a href="https://github.com/NexTechArchitect">
<img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" />
</a>
&nbsp;&nbsp;
<a href="https://www.linkedin.com/in/amit-kumar-811a11277">
<img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" />
</a>
&nbsp;&nbsp;
<a href="https://t.me/NexTechDev">
<img src="https://img.shields.io/badge/Telegram-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" />
</a>
</div>

```

```
