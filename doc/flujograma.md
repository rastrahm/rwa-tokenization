# Flujograma — Ciclo completo RWA Tokenization & Compliance

Flujo extremo a extremo entre inversores KYC, registro de identidades, token permissioned, agente de compliance y distribución de yield (módulo 19, **diseño**).

## Actores

| Actor | Rol |
|-------|-----|
| Emisor / Issuer | Despliega token RWA; configura compliance e identity |
| Investor KYC | Wallet verificada; puede recibir, transferir y claim dividendos |
| Investor no-KYC | Sin identidad; toda transferencia revertirá |
| Claim Issuer | Emite claims ONCHAINID (topics KYC/AML) |
| Compliance Agent | Freeze, pause, `forcedTransfer`, gestiona módulos |
| Dividend Manager | Crea y fondea distribuciones USDC/USDT |
| ModularCompliance | Evalúa reglas (país, max balance, etc.) |
| IdentityRegistry | Fuente de verdad de `isVerified` |
| CI / Foundry | Unit compliance, yield accuracy, recovery, fuzz locks |

---

## Flujograma — Deploy y wiring

```mermaid
flowchart TD
    Start([Inicio]) --> CTR[Deploy ClaimTopicsRegistry + TrustedIssuersRegistry]
    CTR --> IR[Deploy IdentityRegistry]
    IR --> Comp[Deploy ModularCompliance + modules]
    Comp --> Tok[Deploy RWAToken bound a IR + Compliance]
    Tok --> Div[Deploy DividendDistributor bound a RWAToken]
    Div --> Agents[Grant roles: agent, dividend manager]
    Agents --> Ready([Protocolo listo — sin holders aún])
```

---

## Flujograma principal — Onboard → Hold → Transfer → Yield → Recovery

```mermaid
flowchart TD
    Start([Nuevo inversor]) --> KYC[Off-chain KYC / claims]
    KYC --> Reg[IdentityRegistry.registerIdentity]
    Reg --> Ver{isVerified?}
    Ver -->|No| Block([No puede recibir tokens])
    Ver -->|Sí| Mint[Issuer: mint RWA → investor]
    Mint --> Hold[Hold RWAToken]
    Hold --> Tx{¿quiere transferir?}
    Tx -->|Sí| Gate[transfer: verified + compliance + unfrozen]
    Gate -->|OK| Peer[Peer KYC recibe tokens]
    Gate -->|fail| Rev[IdentityNotVerified / TransferNotCompliant / Frozen]
    Hold --> Dist[DividendManager: createDistribution + deposit USDC]
    Dist --> Claim[Holder: claim pro-rata snapshot]
    Hold --> Lost{¿wallet perdida / orden judicial?}
    Lost -->|Sí| Force[Agent: forcedTransfer → nueva identidad verificada]
    Force --> Recovered([Assets recuperados])
    Claim --> Done([Yield cobrado])
    Peer --> Hold
```

---

## Flujograma — Capas de defensa en transferencia

```mermaid
flowchart TD
    A[Intent transfer] --> L1[1. Pause global]
    L1 --> L2[2. Freeze total / parcial]
    L2 --> L3[3. isVerified from]
    L3 --> L4[4. isVerified to]
    L4 --> L5[5. Compliance.canTransfer]
    L5 --> L6[6. Balance unfrozen suficiente]
    L6 --> Ok([_update + transferred hook])
    L1 -.->|fail| X1[TokenPaused]
    L2 -.->|fail| X2[WalletFrozen]
    L3 -.->|fail| X3[IdentityNotVerified]
    L4 -.->|fail| X3
    L5 -.->|fail| X4[TransferNotCompliant]
    L6 -.->|fail| X5[InsufficientUnfrozenBalance]
```

---

## Flujograma — Compliance agent lifecycle

```mermaid
flowchart TD
    A[Evento de riesgo / legal] --> B{¿tipo?}
    B -->|Sanción / AML| F1[setAddressFrozen true]
    B -->|Lock parcial| F2[freezePartialTokens]
    B -->|Emergencia mercado| F3[pause global]
    B -->|Wallet comprometida| F4[forcedTransfer a nueva ID]
    F1 --> Audit[Emit eventos + off-chain audit trail]
    F2 --> Audit
    F3 --> Audit
    F4 --> Audit
    Audit --> C{¿resolver?}
    C -->|unfreeze / unpause| R[Restaurar operatoriedad]
    C -->|mantener| Hold[Estado restringido]
```

---

## Flujograma — Contabilidad de yield (snapshot)

```mermaid
flowchart TD
    Start([Periodo de dividendos]) --> Snap[Tomar snapshotId del RWAToken]
    Snap --> Create[createDistribution totalAmount]
    Create --> Fund[depositPayment USDC/USDT]
    Fund --> Loop[Holders claim]
    Loop --> Calc[claimable = balAt * total / supplyAt]
    Calc --> Pay[Transfer stablecoin]
    Pay --> Acc[claimedAmount += share]
    Acc --> Inv{Σ claimed <= totalAmount?}
    Inv -->|Sí| Ok([Solvente])
    Inv -->|No| Bug([Bug — no debe ocurrir])
```

---

## Flujograma — Tooling Foundry (lab)

```mermaid
flowchart TD
    A[forge build] --> B[Unit: IdentityRegistry isVerified]
    B --> C[Unit: transfer no-KYC → IdentityNotVerified]
    C --> D[Unit: freeze / pause / unfrozen balance]
    D --> E[Unit: forcedTransfer recovery]
    E --> F[Unit: multi-investor yield proportions]
    F --> G[Fuzz: partial freezes + compliance updates]
    G --> H[Invariant: supply + frozen accounting solvency]
    H --> I[Gas snapshot + Deploy.s.sol]
```

---

## Relación con otros docs

| Documento | Contenido |
|-----------|-----------|
| [diagrama-de-clases.md](./diagrama-de-clases.md) | Contratos, interfaces, módulos compliance |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones internas por función |
| [planificacion.md](./planificacion.md) | Fases por dominio RWA (autorización por fase) |
