# Diagrama de flujo — Identity, transfers, freeze, compliance y dividendos

Flujos de decisión internos del protocolo RWA (módulo 19, **v1 implementado**).  
**Sync:** 2026-09-15 · Fases **IDENT → SOLV** ✅ · 80 PASS.

## 1. transfer / transferFrom (permissioned)

```mermaid
flowchart TD
    A[Caller: transfer / transferFrom] --> B{¿paused?}
    B -->|Sí| Z0[Revert TokenPaused]
    B -->|No| C{¿from o to frozen total?}
    C -->|Sí| Z1[Revert WalletFrozen]
    C -->|No| D{isVerified from y to?}
    D -->|No| Z2[Revert IdentityNotVerified]
    D -->|Sí| E{¿amount <= getFreeBalance from?}
    E -->|No| Z3[Revert InsufficientUnfrozenBalance]
    E -->|Sí| F{¿compliance bound?}
    F -->|No| H[_update balances]
    F -->|Sí| G{canTransfer from,to,amount?}
    G -->|No| Z4[Revert TransferNotCompliant]
    G -->|Sí| H
    H --> I[compliance.transferred si bound]
    I --> J[Emit Transfer]
    J --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> Orden real en `_update`: pause → freeze → KYC → free balance → compliance.  
> Si `compliance == address(0)`, se omite `canTransfer` / hooks.

---

## 2. isVerified (Identity Registry)

```mermaid
flowchart TD
    A[isVerified userAddress] --> B{¿identity registrada?}
    B -->|No| No([return false])
    B -->|Sí| C[topics = ClaimTopicsRegistry.getClaimTopics]
    C --> D{¿topics.length == 0?}
    D -->|Sí| Yes([return true — solo registrado])
    D -->|No| E[Para cada topic: Identity.getClaim]
    E --> F{¿valid + issuer trusted + hasClaimTopic?}
    F -->|No| No
    F -->|Sí todos| Yes
```

> Lab: claims los escribe el owner de `Identity` (`addClaim`). No hay verificación criptográfica ONCHAINID de producción.

---

## 3. Freeze total / parcial y pause global

```mermaid
flowchart TD
    A[Agent: pause / freeze / freezePartial] --> B{¿AGENT_ROLE?}
    B -->|No| Z0[Revert AccessControlUnauthorizedAccount]
    B -->|Sí| C{¿acción?}
    C -->|pause| D[paused = true]
    C -->|unpause| E[paused = false]
    C -->|freeze total| F[frozen account = flag]
    C -->|freeze parcial| G{¿amount <= free balance?}
    G -->|No| Z1[Revert InsufficientUnfrozenBalance]
    G -->|Sí| H[frozenTokens += amount]
    D --> I[Emit eventos]
    E --> I
    F --> I
    H --> I
    I --> Ok([Fin — OK; totalSupply intacto])
    Z0 --> End([Fin — revert])
    Z1 --> End
```

> Pause/freeze usan `onlyRole(AGENT_ROLE)` (error OZ AccessControl).  
> `forcedTransfer` usa `UnauthorizedAgent` explícito.

---

## 4. forcedTransfer (recuperación)

```mermaid
flowchart TD
    A[Agent: forcedTransfer from, to, amount] --> B{¿AGENT_ROLE?}
    B -->|No| Z0[Revert UnauthorizedAgent]
    B -->|Sí| C{¿to isVerified?}
    C -->|No| Z1[Revert IdentityNotVerified]
    C -->|Sí| D{¿to frozen?}
    D -->|Sí| Z2[Revert WalletFrozen]
    D -->|No| E{¿balance from >= amount?}
    E -->|No| Z3[Revert InsufficientBalance]
    E -->|Sí| F[Si amount > free: reducir frozenTokens]
    F --> G[_update con flag forced — bypass pause/freeze/KYC from/canTransfer]
    G --> H[compliance.transferred si bound]
    H --> I[Emit ForcedTransfer]
    I --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

---

## 5. Dividendos — createDistribution → depositPayment → claim

```mermaid
flowchart TD
    A[Owner: createDistribution paymentToken, total, snapshotId] --> B{totalSupplyAt snapshot > 0?}
    B -->|No| Z0[Revert InvalidSnapshot]
    B -->|Sí| C[Guardar Distribution funded=false]
    C --> D[Emit DistributionCreated]

    E[Owner: depositPayment distributionId] --> F{¿ya funded?}
    F -->|Sí| Z1[Revert AlreadyFunded]
    F -->|No| G[safeTransferFrom owner → distributor por totalAmount]
    G --> H[funded = true]
    H --> I[Emit DistributionFunded]

    J[Holder: claim distributionId] --> K{¿funded?}
    K -->|No| Z2[Revert DistributionNotFunded]
    K -->|Sí| L{¿ya claimed?}
    L -->|Sí| Z3[Revert AlreadyClaimed]
    L -->|No| M[share = balanceOfAt * total / totalSupplyAt]
    M --> N{¿share > 0?}
    N -->|No| Z4[Revert NothingToClaim]
    N -->|Sí| O[claimed=true; claimedAmount+=share — CEI]
    O --> P[safeTransfer paymentToken → holder]
    P --> Q[Emit Claimed]
    Q --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> `depositPayment(distributionId)` **no** recibe amount: siempre transfiere `totalAmount`.  
> Flooring: `Σ claims ≤ totalAmount` (dust puede quedar en el contrato).

---

## 6. mint (agent → verificado)

```mermaid
flowchart TD
    A[Agent: mint to, amount] --> B{¿AGENT_ROLE?}
    B -->|No| Z0[Revert AccessControlUnauthorizedAccount]
    B -->|Sí| C{amount > 0?}
    C -->|No| Z1[Revert ZeroAmount]
    C -->|Sí| D{isVerified to?}
    D -->|No| Z2[Revert IdentityNotVerified]
    D -->|Sí| E[_mint → _update]
    E --> F{compliance canTransfer 0,to,amount?}
    F -->|No| Z3[Revert TransferNotCompliant]
    F -->|Sí / no bound| G[compliance.created si bound]
    G --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> Mint **no** se bloquea por pause global (solo transfers wallet↔wallet). MaxBalanceModule sí puede rechazar mint.
