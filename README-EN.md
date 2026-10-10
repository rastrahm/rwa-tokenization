# 19 — RWA Tokenization & Compliance Protocols

> 🇪🇸 [Versión en español](./README-ES.md) · [Index](./README.md)

Real-World Asset (RWA) tokenization with **ERC-3643 / T-REX**-style permissioned transfers, Identity Registry, freeze/pause, forced recovery, snapshot-based dividends and modular compliance. Solidity `0.8.24` + Foundry.

**Status:** Phases **IDENT → SOLV** ✅ (module v1 closed).  
**Suite:** `forge test` → **80 PASS**.  
**Docs sync:** 2026-09-15 (diagrams + architecture aligned with the code).

## Docs

| File | Contents |
|------|----------|
| [`doc/README-EN.md`](./doc/README-EN.md) | Documentation index |
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | IDENT→SOLV phases, architecture = code |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | UML (real API) |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Transfer / freeze / yield / compliance |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | End-to-end lifecycle |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix (module-18 style) |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Optimizations + snapshot |
| [`doc/DECISIONES-TECNICAS-EN.md`](./doc/DECISIONES-TECNICAS-EN.md) | Technical decisions, logic and gas improvements |
| [`portfolio/index.html`](./portfolio/index.html) | Portfolio landing page (ES/EN) |

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin **v5.2.0** in `lib/` |
| Guard | `ReentrancyGuardTransient` (claims) |
| EVM | Cancun (`via_ir = true`) |

## Foundry setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copy `.env.example` → `.env`.

## Gas

```bash
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

## v1 scope

- Identity Registry + `isVerified` (ONCHAINID lab)
- Permissioned `RWAToken` (ERC-3643-like)
- Freeze / pause without corrupting supply
- `forcedTransfer` by agent
- Snapshot dividends in USDC/USDT
- Modular compliance (country, max balance)
- Lock fuzzing + invariants + SWC-AUDIT + gas snapshot

Next.js frontend: **out of v1 scope**.
