# 19 — RWA Tokenization & Compliance Protocols

Tokenización de activos reales (RWA) con transfers permissioned estilo **ERC-3643 / T-REX**, Identity Registry, freeze/pause, forced recovery y dividendos por snapshot. Solidity `0.8.24` + Foundry.

**Estado:** Fases **IDENT** ✅ + **TOKEN** ✅ + **LOCK** ✅ + **FORCE** ✅ · resto pendiente de autorización.  
**Suite:** `forge test` → **51 PASS**.

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases por dominio RWA (autorización) |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Transfer / freeze / yield |
| [`doc/flujograma.md`](./doc/flujograma.md) | Ciclo e2e |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin **v5.2.0** en `lib/` |
| EVM | Cancun (`via_ir = true`) |

## Setup Foundry

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Deploy local (Identity stack)

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copiar `.env.example` → `.env`.

## Alcance v1 (planificado)

- Identity Registry + `isVerified` (ONCHAINID lab)
- `RWAToken` permissioned (ERC-3643-like)
- Freeze / pause sin corromper supply
- `forcedTransfer` por agent
- Dividendos snapshot USDC/USDT
- Compliance modular (país, max balance)

Frontend Next.js: **fuera de v1**.
