# Diagrama de flujo — Identity, transfers, freeze y dividendos

Flujos de decisión internos del protocolo RWA (módulo 19, **v1 implementado**).  
**Sync:** 2026-09-14 · Fases **IDENT → SOLV** ✅ · 80 PASS.

## 1. transfer / transferFrom (permissioned)

```mermaid
flowchart TD
    A[Caller: transfer / transferFrom] --> B{¿token paused?}
    B -->|Sí| Z0[Revert TokenPaused]
    B -->|No| C{¿from o to frozen total?}
    C -->|Sí| Z1[Revert WalletFrozen]
    C -->|No| D{¿amount <= balance - frozenTokens?}
    D -->|No| Z2[Revert InsufficientUnfrozenBalance]
    D -->|Sí| E{IdentityRegistry.isVerified from?}
    E -->|No| Z3[Revert IdentityNotVerified]
    E -->|Sí| F{IdentityRegistry.isVerified to?}
    F -->|No| Z3
    F -->|Sí| G{Compliance.canTransfer from,to,amount?}
    G -->|No| Z4[Revert TransferNotCompliant]
    G -->|Sí| H[_update balances — CEI]
    H --> I[compliance.transferred hook]
    I --> J[Emit Transfer]
    J --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> Obligatorio del módulo: **toda** transferencia ejecuta `isVerified` antes de mover tokens.  
> CEI: actualizar estado **antes** de hooks externos de compliance si el módulo hace llamadas externas.

---

## 2. isVerified (Identity Registry)

```mermaid
flowchart TD
    A[isVerified userAddress] --> B{¿identity registrada?}
    B -->|No| No([return false])
    B -->|Sí| C[Leer claim topics requeridos]
    C --> D[Para cada topic: ¿claim válido de trusted issuer?]
    D --> E{¿todos los topics cubiertos?}
    E -->|No| No
    E -->|Sí| Yes([return true])
```

> En lab v1 se puede simplificar a `mapping` de identidades + flag verificado, siempre que la API pública exponga `isVerified` y los tests de no-KYC reviertan con `IdentityNotVerified()`.

---

## 3. Freeze total / parcial y pause global

```mermaid
flowchart TD
    A[Agent: setAddressFrozen / freezePartial / pause] --> B{¿msg.sender es agent?}
    B -->|No| Z0[Revert UnauthorizedAgent]
    B -->|Sí| C{¿acción?}
    C -->|pause| D[paused = true]
    C -->|freeze total| E[frozen account = true]
    C -->|freeze parcial| F{¿amount <= balance libre?}
    F -->|No| Z1[Revert InsufficientUnfrozenBalance]
    F -->|Sí| G[frozenTokens += amount]
    D --> H[Emit AddressFrozen / TokensFrozen / Paused]
    E --> H
    G --> H
    H --> Ok([Fin — OK; totalSupply intacto])
    Z0 --> End([Fin — revert])
    Z1 --> End
```

> Freeze y pause **no** alteran `totalSupply`. Solo restringen movimiento.

---

## 4. forcedTransfer (recuperación / orden judicial)

```mermaid
flowchart TD
    A[Agent: forcedTransfer from, to, amount] --> B{¿msg.sender es agent?}
    B -->|No| Z0[Revert UnauthorizedAgent]
    B -->|Sí| C{¿to isVerified?}
    C -->|No| Z1[Revert IdentityNotVerified]
    C -->|Sí| D{¿balance from >= amount?}
    D -->|No| Z2[Revert Insufficient balance]
    D -->|Sí| E[Si from frozen parcial: ajustar frozenTokens]
    E --> F[_update from → to — bypass canTransfer habitual]
    F --> G[compliance.transferred hook opcional]
    G --> H[Emit ForcedTransfer + Transfer]
    H --> Ok([Fin — OK — recovery])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
```

> El destino **debe** ser identidad verificada (nueva wallet KYC). El origen puede estar frozen/perdido.

---

## 5. Dividendos — createDistribution → deposit → claim

```mermaid
flowchart TD
    A[Agent: createDistribution paymentToken, total, snapshotId] --> B{¿snapshot válido?}
    B -->|No| Z0[Revert InvalidSnapshot]
    B -->|Sí| C[Guardar Distribution + totalSupplyAt]
    C --> D[Emit DistributionCreated]

    E[Agent: depositPayment amount] --> F{¿amount == totalAmount?}
    F -->|No| Z1[Revert / partial funding policy]
    F -->|Sí| G[TransferFrom USDC/USDT → distributor]
    G --> H[funded = true]
    H --> I[Emit DistributionFunded]

    J[Holder: claim distributionId] --> K{¿funded?}
    K -->|No| Z2[Revert DistributionNotFunded]
    K -->|Sí| L{¿ya claimed?}
    L -->|Sí| Z3[Revert AlreadyClaimed]
    L -->|No| M[share = balanceOfAt * total / totalSupplyAt]
    M --> N{¿share > 0?}
    N -->|No| Z4[Revert NothingToClaim]
    N -->|Sí| O[claimed = true — CEI]
    O --> P[Transfer paymentToken share → holder]
    P --> Q[Emit Claimed]
    Q --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    Z4 --> End
```

> Pro-rata por holdings en snapshot. Tests deben cubrir proporciones distintas y ausencia de over-claim / dust excesivo.

---

## 6. mint (solo a verificados)

```mermaid
flowchart TD
    A[Agent/Owner: mint to, amount] --> B{¿autorizado?}
    B -->|No| Z0[Revert UnauthorizedAgent]
    B -->|Sí| C{isVerified to?}
    C -->|No| Z1[Revert IdentityNotVerified]
    C -->|Sí| D[_mint + compliance.created]
    D --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
```
