# 19 — RWA Tokenization & Compliance Protocols

> 🇬🇧 [English version](./README-EN.md) · [Índice](./README.md)

Tokenización de activos reales (RWA) con transfers permissioned estilo **ERC-3643 / T-REX**, Identity Registry, freeze/pause, forced recovery, dividendos por snapshot y compliance modular. Solidity `0.8.24` + Foundry.

**Estado:** Fases **IDENT → SOLV** ✅ (módulo v1 cerrado).  
**Suite:** `forge test` → **80 PASS**.  
**Docs sync:** 2026-09-15 (diagramas + arquitectura alineados al código).

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/README-ES.md`](./doc/README-ES.md) | Índice de documentación |
| [`doc/planificacion-ES.md`](./doc/planificacion-ES.md) | Fases IDENT→SOLV, arquitectura = código |
| [`doc/diagrama-de-clases-ES.md`](./doc/diagrama-de-clases-ES.md) | UML (API real) |
| [`doc/diagrama-de-flujo-ES.md`](./doc/diagrama-de-flujo-ES.md) | Transfer / freeze / yield / compliance |
| [`doc/flujograma-ES.md`](./doc/flujograma-ES.md) | Ciclo e2e |
| [`doc/SWC-AUDIT-ES.md`](./doc/SWC-AUDIT-ES.md) | Matriz SWC-100–136 (estilo módulo 18) |
| [`doc/GAS-ES.md`](./doc/GAS-ES.md) | Optimizaciones + snapshot |
| [`doc/DECISIONES-TECNICAS-ES.md`](./doc/DECISIONES-TECNICAS-ES.md) | Decisiones, lógica y mejoras de gas |
| [`portfolio/index.html`](./portfolio/index.html) | Landing portfolio (ES/EN) |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin **v5.2.0** en `lib/` |
| Guard | `ReentrancyGuardTransient` (claims) |
| EVM | Cancun (`via_ir = true`) |

## Setup Foundry

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copiar `.env.example` → `.env`.

## Gas

```bash
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

## Alcance v1

- Identity Registry + `isVerified` (ONCHAINID lab)
- `RWAToken` permissioned (ERC-3643-like)
- Freeze / pause sin corromper supply
- `forcedTransfer` por agent
- Dividendos snapshot USDC/USDT
- Compliance modular (país, max balance)
- Fuzz locks + invariantes + SWC-AUDIT + gas snapshot

Frontend Next.js: **fuera de v1**.
