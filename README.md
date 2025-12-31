This is an **Ultra-Premium, Dark-Mode Optimized** redesign of your DSC Protocol README.

It uses a **"Cyber-Security / Institutional DeFi"** aesthetic, featuring:

1. **Glassmorphism Headers** (using distinct borders and spacing).
2. **LaTeX Math Rendering** for the formulas.
3. **Interactive-style Navigation**.
4. **High-Contrast "For-the-Badge" Shields**.
5. A completely restructured **Architecture Diagram** using Mermaid.

### **Instructions:**

1. Copy the code block below entirely.
2. Paste it into your repository's `README.md`.

---

```markdown
<div align="center">

  <img src="https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&weight=700&size=30&pause=1000&color=00E5FF&center=true&vCenter=true&width=1000&height=100&lines=DSC+Protocol+v1.0;Decentralized+StableCoin+Engine;Algorithmic+%7C+Over-Collateralized;Secured+by+Foundry+%26+Chainlink" alt="Typing Effect" />

  <br />

  <a href="https://github.com/NexTechArchitect/Foundry-Defi-StableCoin">
    <img src="https://img.shields.io/badge/Solidity-0.8.19-363636?style=for-the-badge&logo=solidity&logoColor=white" />
    <img src="https://img.shields.io/badge/Architecture-Clean_Architecture-be5212?style=for-the-badge&logo=architecture&logoColor=white" />
    <img src="https://img.shields.io/badge/Security-Invariant_Fuzzing-FF4500?style=for-the-badge&logo=shield&logoColor=white" />
    <img src="https://img.shields.io/badge/License-MIT-2ea44f?style=for-the-badge" />
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
      <td align="center" width="16%"><a href="#-mathematical-model"><b>🧮 Math Model</b></a></td>
      <td align="center" width="16%"><a href="#-contract-interfaces"><b>⚙️ Interface</b></a></td>
      <td align="center" width="16%"><a href="#-invariant-security"><b>🛡 Security</b></a></td>
      <td align="center" width="16%"><a href="#-risk-mitigation"><b>⚠️ Risks</b></a></td>
    </tr>
  </table>
</div>

<hr />

## 📖 Executive Summary

The **DSC Protocol** maintains a strict `$1.00` peg for the **DSC Token** through a decentralized, censorship-resistant mechanism. Unlike centralized stablecoins (USDC) or failed algorithmic models (Terra/UST), DSC relies on verifiable on-chain collateral.

> **Core Mechanism:** **Over-Collateralization**
> Users must deposit crypto-assets (`wETH` / `wBTC`) valued significantly higher than the stablecoins they mint. System solvency is enforced by a network of liquidators who profit from purging under-collateralized positions.

---

## 🏗 System Architecture

The protocol enforces a strict **Separation of Concerns (SoC)**. The monetary policy logic is decoupled from the token standard implementation, ensuring upgradeability and cleaner testing surfaces.

### 📐 Data Flow Architecture

```mermaid
graph TD
    User((User))
    Liquidator((Liquidator))
    Oracle{Chainlink Oracle}
    
    subgraph "Core Protocol Layer"
        Engine[DSCEngine.sol<br/>(The Central Bank)]
        Token[DecentralizedStableCoin.sol<br/>(The Currency)]
    end

    subgraph "External Systems"
        WETH[WETH Contract]
        WBTC[WBTC Contract]
    end

    User -->|1. Deposit Collateral| Engine
    Engine -->|2. Lock Assets| WETH
    Engine -.->|3. Verify Value ($)| Oracle
    Engine -->|4. Mint DSC| Token
    Token -->|5. Transfer DSC| User
    
    Liquidator -.->|6. Monitor Health Factor| Engine
    Liquidator -->|7. Liquidate Bad Debt| Engine

```

### 📂 Repository Structure

```text
Foundry-Defi-StableCoin/
├── src/
│   ├── DSCEngine.sol               // Core Logic: Collateral, Minting, Redeeming
│   ├── DecentralizedStableCoin.sol // ERC20 Burnable/Mintable Implementation
│   └── libraries/                  // OracleLib (Stale Price Checks)
├── script/
│   ├── DeployDSC.s.sol             // Deployment Orchestration
│   └── HelperConfig.s.sol          // Multi-chain Configuration (Sepolia/Mainnet)
└── test/
    ├── unit/                       // Function Isolation Tests
    ├── fuzz/                       // Stateless Randomness
    └── invariants/                 // Stateful System Properties (The Gold Standard)

```

---

## 🧮 Mathematical Model

The protocol's stability is guaranteed by the following invariant equations.

### 1. Health Factor ()

The primary metric for solvency. If , the user is subject to immediate liquidation.

* **Threshold:** 50% (User must have double the collateral value vs debt).
* **Precision:** 1e18 standard.

### 2. Liquidation Bonus ()

To incentivize liquidators to pay off bad debt during market crashes, they receive a discount on the collateral they seize.

---

## ⚙️ Contract Interfaces

The `DSCEngine` acts as the primary entry point. Below are the critical function signatures.

### 📥 Deposit & Minting

```solidity
/**
 * @notice Follows CEI (Checks-Effects-Interactions) Pattern
 * @param tokenCollateralAddress The address of the token to deposit
 * @param amountCollateral The amount of collateral to deposit
 * @param amountDscToMint The amount of stablecoin to generate
 */
function depositCollateralAndMintDsc(
    address tokenCollateralAddress,
    uint256 amountCollateral,
    uint256 amountDscToMint
) external;

```

### 🩸 Liquidation Engine

```solidity
/**
 * @notice Liquidates a user who has dropped below the health factor.
 * @notice You receive a 10% bonus for taking this risk.
 * @param collateral The ERC20 collateral address to seize
 * @param user The insolvent user address
 * @param debtToCover The amount of DSC to burn to fix the position
 */
function liquidate(
    address collateral,
    address user,
    uint256 debtToCover
) external moreThanZero(debtToCover) nonReentrant;

```

---

## 🛡 Invariant Security

This protocol has undergone rigorous **Stateful Fuzzing** using Foundry. The following properties are mathematically proven to hold across 10,000+ random transaction sequences.

| ID | Invariant Property | Status |
| --- | --- | --- |
| **INV_01** | **Protocol Solvency:** `Total Collateral Value ($)` > `Total DSC Supply` | ✅ **PASS** |
| **INV_02** | **Getter Safety:** View functions (`getHealthFactor`) never revert/panic. | ✅ **PASS** |
| **INV_03** | **Ledger Integrity:** `wETH` in contract == Sum of all User Balances. | ✅ **PASS** |
| **INV_04** | **Oracle Reliability:** Stale/Broken price feeds cause safe revert. | ✅ **PASS** |

### 🔍 Verification Scope

* **Static Analysis:** Slither, Aderyn.
* **Dynamic Analysis:** Fuzzing (Foundry), Differential Testing.
* **Manual Review:** Access Control, Reentrancy, Oracle Manipulation.

---

## ⚠️ Risk Mitigation

| Risk Vector | Mitigation Strategy |
| --- | --- |
| **Oracle Failure** | Protocol strictly reverts if Chainlink heartbeat is missed or price deviates >50% instantly. |
| **De-pegging** | Arbitrage opportunity created via `redeem` function forces market price back to $1.00. |
| **Network Congestion** | Liquidation threshold set conservatively (200%) to allow ample time for tx inclusion. |
| **Governance Attack** | Contract is **Immutable** and **Non-Upgradeable**. No admin key can rug pull funds. |

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

````
