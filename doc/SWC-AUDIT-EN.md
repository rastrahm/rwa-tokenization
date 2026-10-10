# SWC Audit — RWA Tokenization & Compliance Protocols

> 🇪🇸 [Versión en español](./SWC-AUDIT-ES.md) · [Index](./README.md)

Review of the permissioned RWA protocol (module 19) against the [SWC Registry](https://swcregistry.io/) (EIP-1470). Style aligned with [`18-liquid-staking-protocol/doc/SWC-AUDIT-EN.md`](../../18-liquid-staking-protocol/doc/SWC-AUDIT-EN.md) and [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/RWAToken.sol`,  
`src/IdentityRegistry.sol`,  
`src/Identity.sol`,  
`src/ClaimTopicsRegistry.sol`,  
`src/TrustedIssuersRegistry.sol`,  
`src/ModularCompliance.sol`,  
`src/compliance/CountryRestrictModule.sol`,  
`src/compliance/MaxBalanceModule.sol`,  
`src/DividendDistributor.sol`,  
`src/errors/RWAErrors.sol`,  
`src/interfaces/*`

**Trusted dependencies:** forge-std, OpenZeppelin Contracts v5.2 (`AccessControl`, `Ownable2Step`, `ERC20`, `ReentrancyGuardTransient`, `SafeERC20`)

**Mocks (out of prod):** `MockERC20`  
**Date:** 2026-09-15 (SOLV phase / docs sync · v1 close)  
**Test references:** `test/IdentityRegistry.t.sol`, `test/RWAToken.transfer.t.sol`, `test/FreezePause.t.sol`, `test/ForcedTransfer.t.sol`, `test/DividendDistributor.t.sol`, `test/ModularCompliance.t.sol`, `test/fuzz/TransferLocks.t.sol`, `test/invariant/RWASolvency.invariant.t.sol`, `test/gas/`  
**Index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 32 |
| ⚠️ Informational (RWA design / KYC trust / ops) | 4 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within v1 scope. The token enforces **mandatory KYC** (`IdentityNotVerified`), **pause/freeze** without corrupting supply, agent-gated **`forcedTransfer`** (`UnauthorizedAgent`), **modular compliance** (`TransferNotCompliant`), **dividends** with CEI + `ReentrancyGuardTransient`, and a fixed **`0.8.24`** pragma. Informational risks: trust in the on-chain issuer/agent, `approve` front-running, flooring dust in claims, and lab claims without production ONCHAINID cryptographic signatures.

**Suite / module 19 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `RWAErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + reentrancy guard on claim | ✅ `ReentrancyGuardTransient` |
| `isVerified` on transfer/transferFrom | ✅ `IdentityNotVerified` |
| Freeze/pause without altering `totalSupply` | ✅ + fuzz/invariants |
| `forcedTransfer` agent-only | ✅ `UnauthorizedAgent` |
| Snapshot dividends without over-claim | ✅ |
| Modular compliance country / max balance | ✅ |
| Fuzz ≥ 1000 + invariants | ✅ `foundry.toml` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in RWA tokenization |
|----|-------|---------|--------|------------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility across `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; checks before subtractions (`frozenTokens`, balances); floored claims |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) in every `.sol` |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | Stablecoin via `SafeERC20`; no ETH `.call` in v1 |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | No ETH custody; ERC-20 payouts |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `ReentrancyGuardTransient` + CEI in `DividendDistributor.claim`; compliance hooks after `_update` |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `private` / `immutable` / `public` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | `safeTransfer` reverts if the payment token fails; claim state already set (CEI) — a malicious recipient cannot re-enter |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | ERC-20 `approve` front-running (RWA / USDC) — see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `AccessControl` / `Ownable2Step`; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | No | N/A | No critical logic based on `block.timestamp` |
| SWC-117 | Signature Malleability | Partial | ⚠️ | Lab claims without ECDSA/EIP-712; trust in the `Identity` owner — see risks |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No on-chain RNG |
| SWC-121 | Missing Protection against Signature Replay | Partial | ✅ | Equivalent: one-shot claims per distribution (`AlreadyClaimed`); identities registered by owner |
| SWC-122 | Lack of Proper Signature Verification | Partial | ⚠️ | Lab KYC = claim topic + trusted issuer mapping, no on-chain signature — see risks |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + identity/freeze/forced/yield/compliance tests |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No arbitrary-storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `ERC20, AccessControl, IRWAToken` / `Ownable2Step` on registries |
| SWC-126 | Insufficient Gas Griefing | Partial | ✅ | Module/topic loops O(N) with small N (lab); claim O(1) |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | `isVerified` iterates topics; `canTransfer` iterates modules — bound them in prod |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII in NatSpec/tests |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead variables |
| SWC-132 | Unexpected Ether balance | No | N/A | Contracts do not expect ETH |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | No | N/A | No `abi.encodePacked` of multi-dynamic critical auth data |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | No `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Empty module hooks are intentional (extensibility) |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Country / balances / claims are public by permissioned RWA design |

---

## Informational risks

### SWC-114 — `approve` front-running

**Description:** A third party can front-run allowance changes on the RWA token or on the dividend stablecoin (`depositPayment` / `transferFrom`).

**Status:** ⚠️ Inherent to ERC-20.

**Mitigations:**
- Minimal approvals to the distributor; prefer agent-gated flows.
- `transferFrom` and deposit tests with allowance.

### SWC-117 / SWC-122 — Lab KYC claims

**Description:** `Identity.addClaim` is executed by the identity owner; `isVerified` checks issuer ∈ `TrustedIssuersRegistry` and topics, **without** production ONCHAINID cryptographic signature verification.

**Status:** ⚠️ Lab design / trust in issuer + management key.

**Mitigations:**
- Topics + trusted issuers configurable by the owner.
- Tests for untrusted issuer / incomplete topics → not verified.
- Post-v1: full ONCHAINID with claim signatures.

### Dividend dust (residual SWC-101)

**Description:** `claimable = balAt * total / supplyAt` floors; the sum of claims can be `< totalAmount` (dust stays in the distributor).

**Status:** ⚠️ Expected; does **not** allow over-claiming.

**Mitigation:** Dust tests + fuzz `sum(claims) ≤ total`; CEI prevents double-claim.

### Trust in agent / compliance admin

**Description:** `AGENT_ROLE` can freeze, pause, mint, burn and `forcedTransfer`. The compliance owner can add/remove modules and restrict countries.

**Status:** ⚠️ Permissioned RWA design (not permissionless DeFi).

**Mitigation:** `AccessControl` / `Ownable2Step`; `UnauthorizedAgent` tests; ops through an off-module multisig in prod.

---

## SWC → tests mapping

| SWC | Related test(s) |
|-----|-----------------|
| SWC-101 | `DividendDistributor.t.sol` dust/fuzz; freeze arithmetic |
| SWC-103 | Fixed compiler (`forge build`) |
| SWC-107 | `claim` CEI + `ReentrancyGuardTransient` |
| SWC-114 | `transferFrom` / `depositPayment` approve paths |
| SWC-121 / auth | `ForcedTransfer.t.sol` UnauthorizedAgent; identity owner-only |
| SWC-122 / KYC | `IdentityRegistry.t.sol` untrusted issuer / incomplete topics |
| SWC-123 | Freeze/pause/compliance/forced error paths |
| SWC-128 | ModularCompliance modules loop (N=2 lab) |
| Solvency | `fuzz/TransferLocks.t.sol`, `invariant/RWASolvency.invariant.t.sol` |

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-3643 / T-REX](https://gitlab.com/ERC-3643) (educational design reference)
- [`18-liquid-staking-protocol/doc/SWC-AUDIT-EN.md`](../../18-liquid-staking-protocol/doc/SWC-AUDIT-EN.md)
- [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md)
