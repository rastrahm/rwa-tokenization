# Technical decisions, logic and gas — Module 19 RWA

> 🇪🇸 [Versión en español](./DECISIONES-TECNICAS-ES.md) · [Index](./README.md)

A reading guide to understand **what was built**, **why**, and **where gas can be saved**.  
Aligned with the v1 code (Phases IDENT → SOLV · `forge test` → 80 PASS).

---

## 1. What problem it solves

An RWA token **cannot** behave like an open DeFi ERC-20:

| Need | Solution in this module |
|------|-------------------------|
| Only KYC'd investors move tokens | `IdentityRegistry.isVerified` on every transfer |
| Freeze wallets or the whole market | full/partial freeze + global pause |
| Recover tokens from a lost wallet | `forcedTransfer` by an agent |
| Extra rules (country, balance cap) | `ModularCompliance` + modules |
| Distribute dividends by historical holdings | snapshots + `DividendDistributor` |

Stack: **Solidity `0.8.24` + Foundry + OpenZeppelin v5**.

---

## 2. Technical decisions (and why)

### 2.1 Reference standard: ERC-3643 / T-REX (lab, not a byte-for-byte fork)

The **mental model** of T-REX was adopted (identity + compliance + permissioned token + forced transfer), not a 1:1 copy of the official repo.

**Why:** the module's goal is to understand and demonstrate the RWA flow with Foundry/TDD, not to repackage the production ONCHAINID ecosystem.

**Consequence:** simplified API (lab `Identity` with `addClaim`, no upgradeable proxies and no cryptographic claim signatures).

---

### 2.2 Identity: three contracts + one Identity per wallet

```
ClaimTopicsRegistry    → which claims are mandatory (e.g. KYC = 1)
TrustedIssuersRegistry → who may "issue" those claims
Identity               → a person's claims (topic → issuer)
IdentityRegistry       → wallet → Identity + country; exposes isVerified
```

**`isVerified(user)` is true if:**

1. The wallet has a registered Identity, and  
2. For **every** mandatory topic there is a valid claim whose issuer is trusted **and** authorized for that topic.  
3. If no topics are configured → being registered is enough.

**Why separate registries:** in T-REX, topics and issuers change without redeploying the token; the token only asks `isVerified`.

**Lab tradeoff:** the `Identity` owner writes the claim on-chain. In production, ONCHAINID would validate the claim issuer's signatures.

---

### 2.3 Token: OZ `ERC20` + `AccessControl` + `_update` override

In OpenZeppelin v5, **every** mint/burn/transfer goes through `_update`. The gates are centralized there.

Order for a regular transfer:

1. paused?  
2. from/to fully frozen?  
3. `isVerified(from)` and `isVerified(to)`?  
4. `amount ≤ balance - frozenTokens`?  
5. compliance (if bound) `canTransfer`?  
6. Update lazy snapshots  
7. `super._update` (move balances)  
8. Hook `compliance.transferred` / `created` / `destroyed`

**Why `_update` and not just `transfer`:** it also covers `transferFrom` and mint/burn without duplicating logic.

**Roles:**

| Role | Mechanism | What it does |
|------|-----------|--------------|
| Admin | `DEFAULT_ADMIN_ROLE` | agents, set IR, set compliance |
| Agent | `AGENT_ROLE` | mint, burn, pause, freeze, snapshot, forced |
| Forced auth | manual check → `UnauthorizedAgent` | module-specific error message |

**Why AccessControl and not just Ownable:** multiple compliance agents without sharing a single key.

---

### 2.4 Freeze and pause **without** touching `totalSupply`

- **Pause:** blocks only wallet↔wallet transfers (agent mint still works).  
- **Full freeze:** the wallet can neither send nor receive.  
- **Partial freeze:** `frozenTokens[user]`; spendable = `balance - frozenTokens`.

**Why not burn on freeze:** the asset still exists legally; only movement is restricted (typical RWA requirement / .cursorrules).

After a **burn**, if `frozenTokens > balance`, it is synced downward (`_syncFrozenTokens`).

---

### 2.5 `forcedTransfer`: selective bypass

Legal recovery / compromised wallet:

| Check | Applied? |
|-------|----------|
| Agent | Yes (`UnauthorizedAgent`) |
| `isVerified(to)` | Yes (new KYC wallet) |
| `to` not frozen | Yes |
| Pause / freeze / KYC of `from` / `canTransfer` | **No** (`_forcedTransferInProgress` flag) |
| `compliance.transferred` hook | Yes (if compliance is bound) |

If the amount exceeds the free balance, the needed portion of the source's `frozenTokens` is **automatically unfrozen**.

**Why a flag instead of a separate internal function:** it reuses `_update` (snapshots + balances + hooks) while skipping user-facing gates.

---

### 2.6 Modular compliance (COMP)

```
RWAToken.setCompliance(ModularCompliance)
ModularCompliance.bindToken(token)  // only once
ModularCompliance.addModule(CountryRestrictModule)
ModularCompliance.addModule(MaxBalanceModule)
```

- `canTransfer` = **AND** of all modules.  
- If `compliance == address(0)` → no extra rules (useful in early tests).  
- Hooks can only be called by the bound token (`OnlyBoundToken`).

| Module | Rule |
|--------|------|
| `CountryRestrictModule` | Blocks if the from/to country is restricted (`investorCountry`) |
| `MaxBalanceModule` | `balanceOf(to) + amount ≤ maxBalance` (also on mint) |

**Why separate modules:** add rules without redeploying the token (T-REX pattern).

---

### 2.7 Lazy snapshots (not OZ ERC20Snapshot)

OZ v5 **removed** `ERC20Snapshot`. The lazy pattern was reimplemented:

1. `snapshot()` only increments an id.  
2. On the **next** balance change, the value *before* the change is stored under that id.  
3. `balanceOfAt` / `totalSupplyAt` use binary search; if there is no entry, they return the current balance.

**Why lazy:** no need to iterate over all holders when taking a snapshot (impossible to do cheaply on-chain).

---

### 2.8 Dividends: create → deposit → claim

```
snapshotId = token.snapshot()
createDistribution(USDC, totalAmount, snapshotId)  // stores totalSupplyAt
depositPayment(id)                                 // transferFrom exactly totalAmount
claim(id)                                          // share = balAt * total / supplyAt
```

- Pro-rata with **floor** → dust may remain; **never** over-claim.  
- CEI + `ReentrancyGuardTransient` on `claim`.  
- Double-claim → `AlreadyClaimed`.

**Why snapshot and not current balance:** whoever sells after the cut-off does not take that period's dividend.

---

### 2.9 Custom errors + fixed pragma

- `RWAErrors` library (no `require("string")`).  
- Exact `pragma solidity 0.8.24` (suite + .cursorrules).  
- ETH: no ETH custody; payouts via `SafeERC20`.

---

### 2.10 Domain-based phases (not generic 0–7)

IDENT → TOKEN → LOCK → FORCE → YIELD → COMP → SOLV, each authorized before coding.

**Why:** the RWA domain has natural pieces (identity, locks, recovery, yield, compliance); forcing the "phase 0–7" scheme from other modules added no clarity.

---

## 3. System logic (flows)

### 3.1 Investor onboarding

```
1. Deploy Identity(owner = investor)
2. investor.addClaim(TOPIC_KYC, claimIssuer)
3. issuer registry already lists claimIssuer as trusted for KYC
4. IdentityRegistry.registerIdentity(wallet, identity, country)
5. isVerified(wallet) == true
6. Agent mint(wallet, amount)
```

Without steps 4–5, any transfer to/from that wallet reverts with `IdentityNotVerified`.

---

### 3.2 Regular transfer between two KYC wallets

```
Alice.transfer(Bob, X)
  → _update(Alice, Bob, X)
  → pause? freeze? KYC? free balance? compliance?
  → snapshot update (if a snapshot is pending)
  → balances
  → compliance.transferred
```

---

### 3.3 Forced recovery

```
Agent.forcedTransfer(lostWallet, newKycWallet, X)
  → bypass pause/freeze/KYC(from)/canTransfer
  → require KYC(to) and to not frozen
  → adjust frozenTokens if needed
  → move tokens + transferred hook
```

---

### 3.4 Dividend for one period

```
Agent.snapshot()
Owner.createDistribution(USDC, 10_000e6, snapId)
Owner.approve + depositPayment(distId)
Holder.claim(distId)  // pro-rata by balanceOfAt at snapId
```

Transfers **after** the snapshot do not change that period's share.

---

### 3.5 Contract mental map

```
                    ┌─────────────────────┐
                    │  IdentityRegistry   │◄── isVerified / country
                    └──────────┬──────────┘
                               │
┌──────────────┐    ┌──────────▼──────────┐    ┌────────────────────┐
│ ClaimTopics  │    │      RWAToken       │───►│ ModularCompliance  │
│ TrustedIss.  │    │  ERC20+gates+snap   │    │  Country + MaxBal   │
└──────────────┘    └──────────┬──────────┘    └────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │ DividendDistributor │─── USDC (MockERC20)
                    └─────────────────────┘
```

---

## 4. Gas: current state and how to improve

### 4.1 Current baseline (`.gas-snapshot`)

| Path | Approx. gas | Note |
|------|-------------|------|
| `transfer` (KYC, no compliance bound in the gas test) | ~98 077 | Each transfer = 2× `isVerified` (external calls) |
| `freezePartial` | ~41 244 | Agent + storage only |
| `forcedTransfer` | ~116 855 | Includes a prior freeze in the test |
| `snapshot + create + deposit + claim` | ~287 534 | Full yield cycle |

With **compliance bound** and 2 modules, the transfer cost increases (`canTransfer` loop + hooks).

---

### 4.2 What is already good (don't touch blindly)

| Technique | Effect |
|-----------|--------|
| Custom errors | Cheap reverts |
| `immutable` on registries/modules/distributor | Fewer SLOADs |
| Lazy snapshots | No cloning of all balances |
| `ReentrancyGuardTransient` | Guard without a classic SSTORE |
| `optimizer_runs = 10_000` + `via_ir` | Inlining |

---

### 4.3 Realistic gas improvements (by impact)

Ordered from **highest impact / most natural** to **most invasive**:

#### A. Cache KYC verification (high impact on transfer)

**Problem:** every transfer runs `isVerified(from)` + `isVerified(to)`. Each one may:

- read topics (array in another contract),  
- call `Identity.getClaim` per topic,  
- query trusted issuers.

**Improvement:**  
- a `verified[user]` mapping updated when an identity is registered/removed or topics/claims change; or  
- short-circuit: if there is a single KYC topic, a dedicated function without the generic loop.

**Tradeoff:** the cache must be invalidated when topics/issuers/claims change (events + sync).

#### B. Storage packing in RWAToken (medium impact)

Today: `bool _paused`, `bool _forcedTransferInProgress`, separate mappings.

**Improvement:** pack flags into a `uint256` bitfield; or merge the `frozen` bool using `frozenTokens == type(uint256).max` for a full freeze (a single slot read on the hot path).

**Tradeoff:** readability; freeze tests must be rewritten.

#### C. Avoid empty hooks on every transfer (medium-low impact)

`CountryRestrictModule` / `MaxBalanceModule` have empty `transferred`/`created`/`destroyed`, but the token **always** calls compliance, which iterates over modules.

**Improvement:**  
- a `hooksEnabled` flag in ModularCompliance, or  
- split interface: "check-only" modules vs stateful modules.

**Tradeoff:** less "free" extensibility for stateful modules.

#### D. `isVerified` without in-memory arrays (medium impact)

`getClaimTopics()` copies the array to memory on every call.

**Improvement:** expose `topicCount()` + `topicAt(i)` and read one by one; or cache a hash/list in IdentityRegistry.

#### E. Batch dividend claim (UX / user gas impact)

Several `claim(id)` = N transactions.

**Improvement:** `claimMany(uint256[] ids)`.

**Tradeoff:** loops; watch the gas limit.

#### F. Skip compliance on mint if MaxBalance can live in the token (low / design)

Today mint also goes through `canTransfer(0,to,amount)`.

**Improvement:** inline max balance check on mint (one SLOAD) and keep compliance for transfers only.

**Tradeoff:** duplicate the rule or couple MaxBalance to the token.

#### G. What is **not** worth "optimizing" here

- Removing KYC from transfers → breaks the RWA product.  
- Eager snapshots of all holders → impossible/expensive.  
- Careless `unchecked` in claims → over-claim risk.  
- Lowering `optimizer_runs` too much → code size vs runtime.

---

### 4.4 Practical heuristic

| If the bottleneck is… | Start with… |
|-----------------------|-------------|
| Transfers between holders | Cache / simplify `isVerified` |
| Transfers with many modules | Reduce empty hooks; fewer modules on the hot path |
| Dividend claims | `claimMany`; the floor math is already cheap |
| Deploy / wiring | Already fine for the lab |

Always measure with:

```bash
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

---

## 5. One-line summary per layer

| Layer | Decision |
|-------|----------|
| Identity | Separate registries + `isVerified` as the token's only question |
| Token | Gates in `_update` + agent/admin roles |
| Locks | Freeze/pause without altering supply |
| Recovery | Forced bypasses source rules, not recipient rules |
| Compliance | Pluggable modules; AND; optional |
| Yield | Lazy snapshot + CEI pro-rata claim |
| Gas v1 | Correctness first; hot path is expensive due to external KYC (natural improvement: cache) |
| Process | RWA domain-based phases with authorization |

---

## 6. Further reading

| Doc | What it provides |
|-----|------------------|
| [planificacion-EN.md](./planificacion-EN.md) | Phases, file tree, checklist |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Per-function decisions |
| [flujograma-EN.md](./flujograma-EN.md) | End-to-end lifecycle |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | API / UML |
| [GAS-EN.md](./GAS-EN.md) | Numeric baseline |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 security |

---

*Sync: 2026-09-15 · module v1 closed.*
