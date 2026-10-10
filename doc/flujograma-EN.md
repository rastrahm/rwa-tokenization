# Flowchart — Full RWA Tokenization & Compliance lifecycle

> 🇪🇸 [Versión en español](./flujograma-ES.md) · [Index](./README.md)

End-to-end flow (module 19, **v1 implemented**).  
**Sync:** 2026-09-15 · Phases **IDENT → SOLV** ✅ · 80 PASS.

## Actors

| Actor | Role |
|-------|------|
| Issuer / Admin | Deploy; `DEFAULT_ADMIN_ROLE`; configures IR, compliance, agents |
| Agent | mint/burn, pause, freeze, snapshot, `forcedTransfer` |
| Claim Issuer | Trusted issuer of KYC claims (lab) |
| KYC investor | Verified wallet; holds, transfers, claims dividends |
| Non-KYC investor | No identity; transfer/mint revert |
| ModularCompliance | AND of country / max balance modules |
| IdentityRegistry | Source of `isVerified` + `investorCountry` |
| Dividend manager | Owner of `DividendDistributor` |
| CI / Foundry | Unit, lock fuzzing, invariants, gas, SWC |

---

## Flowchart — Deploy and wiring (v1)

```mermaid
flowchart TD
    Start([Start]) --> CTR[Deploy ClaimTopics + TrustedIssuers]
    CTR --> IR[Deploy IdentityRegistry]
    IR --> Tok[Deploy RWAToken bound to IR]
    Tok --> Comp[Deploy ModularCompliance + Country + MaxBalance]
    Comp --> Wire[bindToken + addModule + token.setCompliance]
    Wire --> Div[Deploy DividendDistributor + MockUSDC]
    Div --> Agents[Admin = agent; topics KYC=1]
    Agents --> Ready([Protocol ready])
```

> Script: `script/Deploy.s.sol`. Env: `.env.example` (`TOKEN_NAME`, `TOKEN_SYMBOL`, `MAX_BALANCE`).

---

## Main flowchart — Onboard → Hold → Transfer → Yield → Recovery

```mermaid
flowchart TD
    Start([New investor]) --> KYC[Identity + KYC claim from trusted issuer]
    KYC --> Reg[IdentityRegistry.registerIdentity]
    Reg --> Ver{isVerified?}
    Ver -->|No| Block([Cannot receive tokens])
    Ver -->|Yes| Mint[Agent: mint RWA]
    Mint --> Hold[Hold RWAToken]
    Hold --> Tx{transfer?}
    Tx -->|Yes| Gate[pause + freeze + KYC + free + compliance]
    Gate -->|OK| Peer[KYC peer receives]
    Gate -->|fail| Rev[IdentityNotVerified / TransferNotCompliant / Frozen / Paused]
    Hold --> Snap[Agent: snapshot]
    Snap --> Dist[DividendManager: create + deposit USDC]
    Dist --> Claim[Holder: pro-rata claim]
    Hold --> Lost{lost wallet / court order?}
    Lost -->|Yes| Force[Agent: forcedTransfer → new verified ID]
    Force --> Recovered([Assets recovered])
    Claim --> Done([Yield collected])
    Peer --> Hold
```

---

## Flowchart — Transfer defense layers

```mermaid
flowchart TD
    A[Transfer intent] --> L1[1. Global pause]
    L1 --> L2[2. Full freeze]
    L2 --> L3[3. isVerified from]
    L3 --> L4[4. isVerified to]
    L4 --> L5[5. Free balance / partial freeze]
    L5 --> L6[6. Compliance.canTransfer — if bound]
    L6 --> Ok([_update + transferred hook])
    L1 -.->|fail| X1[TokenPaused]
    L2 -.->|fail| X2[WalletFrozen]
    L3 -.->|fail| X3[IdentityNotVerified]
    L4 -.->|fail| X3
    L5 -.->|fail| X4[InsufficientUnfrozenBalance]
    L6 -.->|fail| X5[TransferNotCompliant]
```

---

## Flowchart — Compliance agent lifecycle

```mermaid
flowchart TD
    A[Risk / legal event] --> B{type?}
    B -->|Sanction / AML| F1[setAddressFrozen true]
    B -->|Partial lock| F2[freezePartialTokens]
    B -->|Emergency| F3[global pause]
    B -->|Compromised wallet| F4[forcedTransfer to new ID]
    B -->|Restricted country| F5[CountryRestrictModule.setCountryRestricted]
    B -->|Holder cap| F6[MaxBalanceModule.setMaxBalance]
    F1 --> Audit[On-chain events]
    F2 --> Audit
    F3 --> Audit
    F4 --> Audit
    F5 --> Audit
    F6 --> Audit
```

---

## Flowchart — Yield accounting (snapshot)

```mermaid
flowchart TD
    Start([Dividend period]) --> Snap[RWAToken.snapshot]
    Snap --> Create[createDistribution totalAmount]
    Create --> Fund[depositPayment — transferFrom totalAmount]
    Fund --> Loop[Holders claim]
    Loop --> Calc[claimable = balAt * total / supplyAt]
    Calc --> Pay[safeTransfer stablecoin]
    Pay --> Acc[claimedAmount += share]
    Acc --> Inv{Σ claimed <= totalAmount?}
    Inv -->|Yes| Ok([Solvent — dust OK])
    Inv -->|No| Bug([Must never happen])
```

---

## Flowchart — Foundry tooling (lab)

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

## Related docs

| Document | Contents |
|----------|----------|
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | Contracts, interfaces, modules (real API) |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Internal per-function decisions |
| [planificacion-EN.md](./planificacion-EN.md) | IDENT→SOLV phases (closed) |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline |
