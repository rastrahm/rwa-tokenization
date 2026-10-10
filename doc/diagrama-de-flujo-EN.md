# Flow diagram — Identity, transfers, freeze, compliance and dividends

> 🇪🇸 [Versión en español](./diagrama-de-flujo-ES.md) · [Index](./README.md)

Internal decision flows of the RWA protocol (module 19, **v1 implemented**).  
**Sync:** 2026-09-15 · Phases **IDENT → SOLV** ✅ · 80 PASS.

## 1. transfer / transferFrom (permissioned)

```mermaid
flowchart TD
    A[Caller: transfer / transferFrom] --> B{paused?}
    B -->|Yes| Z0[Revert TokenPaused]
    B -->|No| C{from or to fully frozen?}
    C -->|Yes| Z1[Revert WalletFrozen]
    C -->|No| D{isVerified from and to?}
    D -->|No| Z2[Revert IdentityNotVerified]
    D -->|Yes| E{amount <= getFreeBalance from?}
    E -->|No| Z3[Revert InsufficientUnfrozenBalance]
    E -->|Yes| F{compliance bound?}
    F -->|No| H[_update balances]
    F -->|Yes| G{canTransfer from,to,amount?}
    G -->|No| Z4[Revert TransferNotCompliant]
    G -->|Yes| H
    H --> I[compliance.transferred if bound]
    I --> J[Emit Transfer]
    J --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> Actual order in `_update`: pause → freeze → KYC → free balance → compliance.  
> If `compliance == address(0)`, `canTransfer` / hooks are skipped.

---

## 2. isVerified (Identity Registry)

```mermaid
flowchart TD
    A[isVerified userAddress] --> B{identity registered?}
    B -->|No| No([return false])
    B -->|Yes| C[topics = ClaimTopicsRegistry.getClaimTopics]
    C --> D{topics.length == 0?}
    D -->|Yes| Yes([return true — registered only])
    D -->|No| E[For each topic: Identity.getClaim]
    E --> F{valid + trusted issuer + hasClaimTopic?}
    F -->|No| No
    F -->|Yes for all| Yes
```

> Lab: claims are written by the `Identity` owner (`addClaim`). There is no production-grade ONCHAINID cryptographic verification.

---

## 3. Full / partial freeze and global pause

```mermaid
flowchart TD
    A[Agent: pause / freeze / freezePartial] --> B{AGENT_ROLE?}
    B -->|No| Z0[Revert AccessControlUnauthorizedAccount]
    B -->|Yes| C{action?}
    C -->|pause| D[paused = true]
    C -->|unpause| E[paused = false]
    C -->|full freeze| F[frozen account = flag]
    C -->|partial freeze| G{amount <= free balance?}
    G -->|No| Z1[Revert InsufficientUnfrozenBalance]
    G -->|Yes| H[frozenTokens += amount]
    D --> I[Emit events]
    E --> I
    F --> I
    H --> I
    I --> Ok([End — OK; totalSupply untouched])
    Z0 --> End([End — revert])
    Z1 --> End
```

> Pause/freeze use `onlyRole(AGENT_ROLE)` (OZ AccessControl error).  
> `forcedTransfer` uses an explicit `UnauthorizedAgent`.

---

## 4. forcedTransfer (recovery)

```mermaid
flowchart TD
    A[Agent: forcedTransfer from, to, amount] --> B{AGENT_ROLE?}
    B -->|No| Z0[Revert UnauthorizedAgent]
    B -->|Yes| C{to isVerified?}
    C -->|No| Z1[Revert IdentityNotVerified]
    C -->|Yes| D{to frozen?}
    D -->|Yes| Z2[Revert WalletFrozen]
    D -->|No| E{balance from >= amount?}
    E -->|No| Z3[Revert InsufficientBalance]
    E -->|Yes| F[If amount > free: reduce frozenTokens]
    F --> G[_update with forced flag — bypass pause/freeze/KYC from/canTransfer]
    G --> H[compliance.transferred if bound]
    H --> I[Emit ForcedTransfer]
    I --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

---

## 5. Dividends — createDistribution → depositPayment → claim

```mermaid
flowchart TD
    A[Owner: createDistribution paymentToken, total, snapshotId] --> B{totalSupplyAt snapshot > 0?}
    B -->|No| Z0[Revert InvalidSnapshot]
    B -->|Yes| C[Store Distribution funded=false]
    C --> D[Emit DistributionCreated]

    E[Owner: depositPayment distributionId] --> F{already funded?}
    F -->|Yes| Z1[Revert AlreadyFunded]
    F -->|No| G[safeTransferFrom owner → distributor for totalAmount]
    G --> H[funded = true]
    H --> I[Emit DistributionFunded]

    J[Holder: claim distributionId] --> K{funded?}
    K -->|No| Z2[Revert DistributionNotFunded]
    K -->|Yes| L{already claimed?}
    L -->|Yes| Z3[Revert AlreadyClaimed]
    L -->|No| M[share = balanceOfAt * total / totalSupplyAt]
    M --> N{share > 0?}
    N -->|No| Z4[Revert NothingToClaim]
    N -->|Yes| O[claimed=true; claimedAmount+=share — CEI]
    O --> P[safeTransfer paymentToken → holder]
    P --> Q[Emit Claimed]
    Q --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> `depositPayment(distributionId)` does **not** take an amount: it always transfers `totalAmount`.  
> Flooring: `Σ claims ≤ totalAmount` (dust may remain in the contract).

---

## 6. mint (agent → verified)

```mermaid
flowchart TD
    A[Agent: mint to, amount] --> B{AGENT_ROLE?}
    B -->|No| Z0[Revert AccessControlUnauthorizedAccount]
    B -->|Yes| C{amount > 0?}
    C -->|No| Z1[Revert ZeroAmount]
    C -->|Yes| D{isVerified to?}
    D -->|No| Z2[Revert IdentityNotVerified]
    D -->|Yes| E[_mint → _update]
    E --> F{compliance canTransfer 0,to,amount?}
    F -->|No| Z3[Revert TransferNotCompliant]
    F -->|Yes / not bound| G[compliance.created if bound]
    G --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> Mint is **not** blocked by the global pause (only wallet↔wallet transfers are). MaxBalanceModule can still reject a mint.
