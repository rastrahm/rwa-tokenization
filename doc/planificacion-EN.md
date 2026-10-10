# Planning — Module 19: RWA Tokenization & Compliance Protocols

> 🇪🇸 [Versión en español](./planificacion-ES.md) · [Index](./README.md)

**Status:** Phases **IDENT → SOLV** ✅ (module v1 closed).  
**Progress rule:** the per-phase authorization rule applied during construction; v1 has no pending phases.  
**Suite:** `forge test` → **80 PASS**.  
**Docs sync:** 2026-09-15 — diagrams and file tree aligned with the code.  
**Design note:** phases do **not** follow the generic 0–7 scheme of previous modules; they are organized by **RWA compliance domains**.

---

## 1. Goal

Build a permissioned **Real-World Asset (RWA) tokenization** system that can:

- Issue a **restricted ERC-20** token aligned with **ERC-3643 / T-REX**.
- Verify identities through an **Identity Registry** (ONCHAINID / claims) before any `transfer` / `transferFrom`.
- Apply **modular compliance** (country, max balance, etc.) without breaking supply accounting.
- Freeze wallets (**full/partial freeze**) and **pause** the token globally.
- Execute **forced transfers** by an authorized agent (legal recovery / lost wallet).
- Distribute **pro-rata dividends** (USDC/USDT) based on holdings at a **snapshot**.

Stack: **Foundry + Solidity `0.8.24`**. The Next.js frontend is **out of v1 scope**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `IdentityRegistry` + `isVerified` | Full ONCHAINID with production upgradeable proxies |
| `ClaimTopicsRegistry` + `TrustedIssuersRegistry` (lab) | Real integration with off-chain KYC providers |
| Permissioned `RWAToken` (ERC-3643-like) | Secondary market / DEX listing compliance |
| `ModularCompliance` + ≥2 modules (country, max balance) | Off-chain rules engine / ZK-KYC |
| Full freeze, partial freeze, global pause | Multi-sig governance time-locks |
| `forcedTransfer` by agent | Automated court oracle |
| `DividendDistributor` snapshot + USDC/USDT claim | Streaming yield / RWA token rebase |
| Tests: compliance failure, yield accuracy, recovery, lock fuzzing | Next.js frontend (App Router) |
| `Deploy.s.sol` + gas snapshot + SWC-AUDIT | Legal packaging for mainnet issuance |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x (`AccessControl` / `Ownable2Step`, `ERC20`, `ReentrancyGuardTransient`, `SafeERC20`). Custom lazy snapshots in `RWAToken` (OZ v5 no longer ships ERC20Snapshot).
- Foundry: unit + fuzz (`runs >= 1000`) + invariant + gas.
- **Custom errors** (no `require` strings).
- Strict CEI; external tokens via `safeTransfer` / return-value checks.
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests first in every contract phase.

### Module 19 (local `.cursorrules`)

- Every `transfer` / `transferFrom` → `isVerified` → `error IdentityNotVerified()`.
- Agent/compliance manager → `forcedTransfer` for recovery.
- Snapshot / pro-rata dividends in USDC/USDT.
- Individual freeze + global pause **without** corrupting `totalSupply`.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI: registry (view), gated transfer, dividend claim, agent panel.
- App Router, Zod, Vitest + RTL, JSDoc, no `any`.
- **Out** of the phases in this plan.

---

## 4. Architecture (v1 implemented)

```
19-rwa-tokenization/
├── README.md               # bilingual index
├── README-ES.md
├── README-EN.md
├── .cursorrules
├── .gitignore
├── .env.example
├── .gas-snapshot
├── foundry.toml
├── remappings.txt
├── doc/                    # every doc in -ES.md and -EN.md
│   ├── README.md           # bilingual index
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   ├── GAS-{ES,EN}.md
│   └── DECISIONES-TECNICAS-{ES,EN}.md
├── portfolio/
│   ├── index.html
│   └── i18n.js
├── src/
│   ├── Identity.sol
│   ├── IdentityRegistry.sol
│   ├── ClaimTopicsRegistry.sol
│   ├── TrustedIssuersRegistry.sol
│   ├── RWAToken.sol
│   ├── ModularCompliance.sol
│   ├── DividendDistributor.sol
│   ├── interfaces/
│   │   ├── IIdentity.sol
│   │   ├── IIdentityRegistry.sol
│   │   ├── IClaimTopicsRegistry.sol
│   │   ├── ITrustedIssuersRegistry.sol
│   │   ├── IRWAToken.sol
│   │   ├── ICompliance.sol
│   │   └── IDividendDistributor.sol
│   ├── compliance/
│   │   ├── CountryRestrictModule.sol
│   │   └── MaxBalanceModule.sol
│   ├── errors/
│   │   └── RWAErrors.sol
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── IdentityRegistry.t.sol
│   ├── RWAToken.transfer.t.sol
│   ├── FreezePause.t.sol
│   ├── ForcedTransfer.t.sol
│   ├── DividendDistributor.t.sol
│   ├── ModularCompliance.t.sol
│   ├── helpers/RWATestBase.sol
│   ├── fuzz/TransferLocks.t.sol
│   ├── invariant/
│   │   ├── RWAHandler.sol
│   │   └── RWASolvency.invariant.t.sol
│   └── gas/RWAToken.gas.t.sol
└── script/
    └── Deploy.s.sol
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `Identity` | Lab claims (topic → issuer) managed by the owner |
| `IdentityRegistry` | Register/remove identities; `isVerified` |
| `ClaimTopicsRegistry` | Required KYC topics |
| `TrustedIssuersRegistry` | Trusted claim issuers |
| `RWAToken` | Permissioned ERC-20: KYC + pause + freeze + forcedTransfer + snapshots |
| `DividendDistributor` | Snapshot → pro-rata stablecoin claim |
| `ModularCompliance` | Aggregates `canTransfer` modules + hooks |
| `CountryRestrictModule` | Blocks restricted countries |
| `MaxBalanceModule` | Per-wallet balance cap |
| `MockERC20` | Lab USDC/USDT |

---

## 5. Custom errors (module)

```solidity
error IdentityNotVerified();       // mandatory (.cursorrules)
error TransferNotCompliant();
error WalletFrozen();
error InsufficientUnfrozenBalance();
error InsufficientBalance();
error TokenPaused();
error TokenNotPaused();
error UnauthorizedAgent();
error ZeroAddress();
error ZeroAmount();
error AlreadyClaimed();
error NothingToClaim();
error InvalidSnapshot();
error InvalidDistribution();
error DistributionNotFunded();
error AlreadyFunded();
error InvalidCountry();
error TopicAlreadyExists();
error TopicDoesNotExist();
error IssuerAlreadyExists();
error IssuerDoesNotExist();
error IdentityAlreadyRegistered();
error IdentityNotRegistered();
error ClaimTopicNotAllowed();
error ModuleAlreadyAdded();
error ModuleNotFound();
error TokenAlreadyBound();
error OnlyBoundToken();
error OnlyCompliance();
```

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *“I authorize Phase \<ID\>”*. |
| **Delivery** | On close: acceptance checklist + touched files. |
| **Blocking** | New scope → document it and wait for a new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |
| **IDs** | Phases named after RWA domains (no generic 0–7 numbering). |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| **IDENT** | Foundry scaffold + Identity Registry (`isVerified`) | ✅ Done | ✅ Authorized |
| **TOKEN** | Permissioned `RWAToken` (ERC-3643 gated transfer) | ✅ Done | ✅ Authorized |
| **LOCK** | Global pause + full/partial freeze | ✅ Done | ✅ Authorized |
| **FORCE** | Agent `forcedTransfer` / asset recovery | ✅ Done | ✅ Authorized |
| **YIELD** | `DividendDistributor` snapshot USDC/USDT | ✅ Done | ✅ Authorized |
| **COMP** | `ModularCompliance` + country / max balance modules | ✅ Done | ✅ Authorized |
| **SOLV** | Suite: lock fuzzing + invariants + Deploy/gas + SWC-AUDIT | ✅ Done | ✅ Authorized |

**How to authorize:** module v1 closed; no pending phases.

---

## 7. Phase details

### Phase IDENT — Scaffold + Identity Registry ✅

**Goal:** compilable Foundry repo and on-chain identity with a reliable `isVerified`.

1. Scaffold: `foundry.toml` (solc `0.8.24`, fuzz `runs >= 1000`), OZ v5, `src/`, `test/`, `script/` folders.
2. `RWAErrors.sol` with `IdentityNotVerified` and base errors.
3. `ClaimTopicsRegistry` + `TrustedIssuersRegistry` (minimal lab).
4. `IdentityRegistry`: `registerIdentity`, `deleteIdentity`, `isVerified`.
5. TDD: verified vs not verified; incomplete topics → `false`.

**Exit criteria:** `forge build` + identity tests green.

**Depends on:** nothing (first code phase).

**Done (2026-09-14):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`).
- `remappings.txt`; deps in `lib/` (forge-std, OpenZeppelin **v5.2.0**, copied from module 18).
- `RWAErrors.sol`, `Identity.sol`, `ClaimTopicsRegistry`, `TrustedIssuersRegistry`, `IdentityRegistry`.
- `isVerified`: registered + every topic has a claim from a trusted issuer authorized for that topic.
- Tests: `IdentityRegistry.t.sol` (unit + fuzz 1000).
- Stub `script/Deploy.s.sol`, `.env.example`, `README.md`.
- **`forge test` → 17 PASS**.

---

### Phase TOKEN — Permissioned RWAToken ✅

**Goal:** ERC-20 whose transfers require KYC on both `from` and `to`.

1. TDD first: transfer between non-KYC → `IdentityNotVerified`; KYC↔KYC OK.
2. `RWAToken` + binding to `IdentityRegistry`.
3. `mint` only to verified addresses; `transfer` / `transferFrom` with mandatory check.
4. Agent/owner roles via `AccessControl` or `Ownable2Step`.

**Exit criteria:** compliance-failure transfer suite green.

**Depends on:** IDENT.

**Done (2026-09-14):**
- `IRWAToken` + `RWAToken` (OZ `ERC20` + `AccessControl`, `AGENT_ROLE`).
- `_update`: wallet-to-wallet transfers require `isVerified(from)` and `isVerified(to)`.
- `mint` agent-only → verified recipient; `burn` agent-only.
- Helper `test/helpers/RWATestBase.sol`; tests `RWAToken.transfer.t.sol` (unit + fuzz).
- `Deploy.s.sol` deploys identity stack + token.
- **`forge test` → 30 PASS**.

---

### Phase LOCK — Modular pause and freeze ✅

**Goal:** restrict movement without altering `totalSupply`.

1. TDD: pause blocks transfers; full freeze; partial freeze leaves free balance usable.
2. `pause` / `unpause`, `setAddressFrozen`, `freezePartialTokens` / `unfreezePartialTokens`.
3. Accounting: `balance - frozenTokens` as spendable.
4. Agents only.

**Exit criteria:** freeze/pause tests + supply-intact invariant.

**Depends on:** TOKEN.

**Done (2026-09-14):**
- `pause` / `unpause`, `setAddressFrozen`, `freezePartialTokens` / `unfreezePartialTokens` (`AGENT_ROLE` only).
- `_update`: pause + full freeze + free balance on wallet↔wallet transfers.
- `getFreeBalance`; `frozenTokens` sync after burn if balance < frozen.
- Agent mint allowed while paused (only transfers are blocked).
- Tests: `FreezePause.t.sol` (unit + supply fuzz).
- **`forge test` → 40 PASS**.

---

### Phase FORCE — Forced transfer / recovery ✅

**Goal:** an agent recovers tokens to a new verified identity.

1. TDD: agent moves tokens from a frozen/lost wallet → new KYC wallet; non-agent reverts `UnauthorizedAgent`.
2. Recipient must pass `isVerified`.
3. Adjust `frozenTokens` when applicable; `ForcedTransfer` events.
4. Bypass freeze rules on `from` (legal recovery) while keeping checks on `to`.

**Exit criteria:** forced recovery tests green.

**Depends on:** LOCK.

**Done (2026-09-14):**
- `forcedTransfer(from, to, amount)` agent-only → otherwise `UnauthorizedAgent`.
- Bypasses pause, freeze and `isVerified` on `from`; requires `isVerified(to)` and `to` not frozen.
- Adjusts source `frozenTokens` when moving frozen balance; emits `ForcedTransfer` + `TokensUnfrozen`.
- Tests: `ForcedTransfer.t.sol` (recovery, pause, partial freeze, supply fuzz).
- **`forge test` → 51 PASS**.

---

### Phase YIELD — DividendDistributor ✅

**Goal:** holders claim USDC/USDT pro-rata based on a historical snapshot.

1. TDD: 2–3 investors with different proportions; sum of claims ≤ total; no double-claim.
2. RWA token snapshot (OZ `ERC20Snapshot` / v5 checkpoints equivalent).
3. `createDistribution` → `depositPayment` → `claim`.
4. CEI + `ReentrancyGuard` on claim.

**Exit criteria:** yield claim accuracy tests (no abusive dust / excess claim).

**Depends on:** TOKEN.

**Done (2026-09-14):**
- Lazy snapshots in `RWAToken` (ERC20Snapshot style; OZ v5 does not ship it): `snapshot`, `balanceOfAt`, `totalSupplyAt`.
- `DividendDistributor`: create → deposit → pro-rata claim; CEI + `ReentrancyGuardTransient`.
- `MockERC20` lab USDC (6 decimals).
- Tests: exact 60/30/10, post-snapshot transfer, dust ≤ total, no-over-claim fuzz.
- **`forge test` → 60 PASS**.

---

### Phase COMP — ModularCompliance ✅

**Goal:** composable rules on top of base KYC.

1. `ModularCompliance.bindToken` + modules array.
2. v1 modules: `CountryRestrictModule`, `MaxBalanceModule`.
3. `RWAToken.transfer` queries `canTransfer` after `isVerified`.
4. TDD: restricted country / exceeded max balance → `TransferNotCompliant`.

**Exit criteria:** per-module tests + KYC+compliance combination.

**Depends on:** TOKEN.

**Done (2026-09-14):**
- `ModularCompliance` + `CountryRestrictModule` + `MaxBalanceModule`.
- `RWAToken.setCompliance`; `_update` calls `canTransfer` (transfers + mint) and post-movement hooks.
- `forcedTransfer` bypasses `canTransfer` but runs the `transferred` hook.
- Tests: restricted country, max balance, KYC still mandatory, remove module.
- Deploy wires compliance + modules.
- **`forge test` → 69 PASS**.

---

### Phase SOLV — Hardening, fuzzing, deploy and v1 close ✅

**Goal:** prove solvency under partial freezes and changing rules; close the lab.

1. Fuzz: random partial freezes + compliance updates; consistent supply and balances.
2. Invariants: `Σ balances == totalSupply`; frozen ≤ balance; claims ≤ distribution.
3. `Deploy.s.sol`, `.env.example`, full NatSpec, gas snapshot.
4. `doc/SWC-AUDIT` + `doc/GAS` + diagram sync if there were deviations.
5. Mark phases ✅ in this document.

**Exit criteria:** `forge test` (unit + fuzz + invariant) green; local deploy OK.

**Depends on:** IDENT + TOKEN + LOCK + FORCE + YIELD + COMP.

**Done (2026-09-14):**
- `test/fuzz/TransferLocks.t.sol` — partial freeze, max balance, country toggle, forced.
- `test/invariant/RWASolvency.invariant.t.sol` + `RWAHandler` — supply conserved, frozen ≤ balance.
- `test/gas/RWAToken.gas.t.sol` + `.gas-snapshot`.
- `doc/SWC-AUDIT` (SWC-100–136 matrix, module-18 style), `doc/GAS`, `doc/README`.
- Deploy already wired the COMP + yield stack.
- **`forge test` → 80 PASS**.

---

## 8. Global acceptance checklist (v1)

- [x] Identity Registry + `isVerified` operational (Phase IDENT)
- [x] Every `transfer` / `transferFrom` calls `isVerified` → `IdentityNotVerified`
- [x] Full/partial freeze and pause without corrupting `totalSupply`
- [x] Agent can `forcedTransfer` to a verified identity
- [x] Snapshot dividends: correct proportions, no over-claim
- [x] Modular compliance rejects non-compliant transfers
- [x] Lock fuzzing + solvency invariants green
- [x] CEI + custom errors + NatSpec + solc `0.8.24`
- [x] Next.js frontend **not** included (post-v1)
- [x] `doc/SWC-AUDIT` (module-18 style)
- [x] Gas snapshot + `Deploy.s.sol`

---

## 9. Next step

**Module v1 closed (Phases IDENT → SOLV ✅).**  
Optional post-v1: Next.js frontend, ONCHAINID with claim signatures, multi-sig agent quorum, more compliance modules.
