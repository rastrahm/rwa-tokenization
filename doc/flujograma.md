# Flujograma — Ciclo completo RWA Tokenization & Compliance

Flujo extremo a extremo (módulo 19, **v1 implementado**).  
**Sync:** 2026-09-15 · Fases **IDENT → SOLV** ✅ · 80 PASS.

## Actores

| Actor | Rol |
|-------|-----|
| Emisor / Admin | Deploy; `DEFAULT_ADMIN_ROLE`; configura IR, compliance, agents |
| Agent | mint/burn, pause, freeze, snapshot, `forcedTransfer` |
| Claim Issuer | Emisor confiable de claims KYC (lab) |
| Investor KYC | Wallet verificada; hold, transfer, claim dividendos |
| Investor no-KYC | Sin identidad; transfer/mint revierten |
| ModularCompliance | AND de módulos país / max balance |
| IdentityRegistry | Fuente de `isVerified` + `investorCountry` |
| Dividend manager | Owner del `DividendDistributor` |
| CI / Foundry | Unit, fuzz locks, invariantes, gas, SWC |

---

## Flujograma — Deploy y wiring (v1)

```mermaid
flowchart TD
    Start([Inicio]) --> CTR[Deploy ClaimTopics + TrustedIssuers]
    CTR --> IR[Deploy IdentityRegistry]
    IR --> Tok[Deploy RWAToken bound a IR]
    Tok --> Comp[Deploy ModularCompliance + Country + MaxBalance]
    Comp --> Wire[bindToken + addModule + token.setCompliance]
    Wire --> Div[Deploy DividendDistributor + MockUSDC]
    Div --> Agents[Admin = agent; topics KYC=1]
    Agents --> Ready([Protocolo listo])
```

> Script: `script/Deploy.s.sol`. Env: `.env.example` (`TOKEN_NAME`, `TOKEN_SYMBOL`, `MAX_BALANCE`).

---

## Flujograma principal — Onboard → Hold → Transfer → Yield → Recovery

```mermaid
flowchart TD
    Start([Nuevo inversor]) --> KYC[Identity + claim KYC de trusted issuer]
    KYC --> Reg[IdentityRegistry.registerIdentity]
    Reg --> Ver{isVerified?}
    Ver -->|No| Block([No puede recibir tokens])
    Ver -->|Sí| Mint[Agent: mint RWA]
    Mint --> Hold[Hold RWAToken]
    Hold --> Tx{¿transferir?}
    Tx -->|Sí| Gate[pause + freeze + KYC + free + compliance]
    Gate -->|OK| Peer[Peer KYC recibe]
    Gate -->|fail| Rev[IdentityNotVerified / TransferNotCompliant / Frozen / Paused]
    Hold --> Snap[Agent: snapshot]
    Snap --> Dist[DividendManager: create + deposit USDC]
    Dist --> Claim[Holder: claim pro-rata]
    Hold --> Lost{¿wallet perdida / orden?}
    Lost -->|Sí| Force[Agent: forcedTransfer → nueva ID verificada]
    Force --> Recovered([Assets recuperados])
    Claim --> Done([Yield cobrado])
    Peer --> Hold
```

---

## Flujograma — Capas de defensa en transferencia

```mermaid
flowchart TD
    A[Intent transfer] --> L1[1. Pause global]
    L1 --> L2[2. Freeze total]
    L2 --> L3[3. isVerified from]
    L3 --> L4[4. isVerified to]
    L4 --> L5[5. Free balance / freeze parcial]
    L5 --> L6[6. Compliance.canTransfer — si bound]
    L6 --> Ok([_update + transferred hook])
    L1 -.->|fail| X1[TokenPaused]
    L2 -.->|fail| X2[WalletFrozen]
    L3 -.->|fail| X3[IdentityNotVerified]
    L4 -.->|fail| X3
    L5 -.->|fail| X4[InsufficientUnfrozenBalance]
    L6 -.->|fail| X5[TransferNotCompliant]
```

---

## Flujograma — Compliance agent lifecycle

```mermaid
flowchart TD
    A[Evento de riesgo / legal] --> B{¿tipo?}
    B -->|Sanción / AML| F1[setAddressFrozen true]
    B -->|Lock parcial| F2[freezePartialTokens]
    B -->|Emergencia| F3[pause global]
    B -->|Wallet comprometida| F4[forcedTransfer a nueva ID]
    B -->|País restringido| F5[CountryRestrictModule.setCountryRestricted]
    B -->|Cap holder| F6[MaxBalanceModule.setMaxBalance]
    F1 --> Audit[Eventos on-chain]
    F2 --> Audit
    F3 --> Audit
    F4 --> Audit
    F5 --> Audit
    F6 --> Audit
```

---

## Flujograma — Contabilidad de yield (snapshot)

```mermaid
flowchart TD
    Start([Periodo de dividendos]) --> Snap[RWAToken.snapshot]
    Snap --> Create[createDistribution totalAmount]
    Create --> Fund[depositPayment — transferFrom totalAmount]
    Fund --> Loop[Holders claim]
    Loop --> Calc[claimable = balAt * total / supplyAt]
    Calc --> Pay[safeTransfer stablecoin]
    Pay --> Acc[claimedAmount += share]
    Acc --> Inv{Σ claimed <= totalAmount?}
    Inv -->|Sí| Ok([Solvente — dust OK])
    Inv -->|No| Bug([No debe ocurrir])
```

---

## Flujograma — Tooling Foundry (lab)

```mermaid
flowchart TD
    A[forge build] --> B[Unit: IdentityRegistry]
    B --> C[Unit: RWAToken transfer KYC]
    C --> D[Unit: FreezePause]
    D --> E[Unit: ForcedTransfer]
    E --> F[Unit: DividendDistributor]
    F --> G[Unit: ModularCompliance]
    G --> H[Fuzz: TransferLocks]
    H --> I[Invariant: RWASolvency]
    I --> J[Gas: RWATokenGasTest + snapshot]
    J --> K[forge test → 80 PASS]
```

---

## Relación con otros docs

| Documento | Contenido |
|-----------|-----------|
| [diagrama-de-clases.md](./diagrama-de-clases.md) | Contratos, interfaces, módulos (API real) |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones internas por función |
| [planificacion.md](./planificacion.md) | Fases IDENT→SOLV cerradas |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 |
| [GAS.md](./GAS.md) | Baseline gas |
