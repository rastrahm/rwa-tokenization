# Auditoría SWC — RWA Tokenization & Compliance Protocols

Verificación del protocolo RWA permissioned (módulo 19) contra el [SWC Registry](https://swcregistry.io/) (EIP-1470). Estilo alineado a [`18-liquid-staking-protocol/doc/SWC-AUDIT.md`](../../18-liquid-staking-protocol/doc/SWC-AUDIT.md) y [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
`src/RWAToken.sol`,  
`src/IdentityRegistry.sol`,  
`src/Identity.sol`,  
`src/ClaimTopicsRegistry.sol`,  
`src/TrustedIssuersRegistry.sol`,  
`src/ModularCompliance.sol`,  
`src/compliance/CountryRestrictModule.sol`,  
`src/compliance/MaxBalanceModule.sol`,  
`src/DividendDistributor.sol`,  
`src/errors/RWAErrors.sol`,  
`src/interfaces/*`

**Dependencias de confianza:** forge-std, OpenZeppelin Contracts v5.2 (`AccessControl`, `Ownable2Step`, `ERC20`, `ReentrancyGuardTransient`, `SafeERC20`)

**Mocks (fuera de prod):** `MockERC20`  
**Fecha:** 2026-09-15 (Fase SOLV / docs sync · cierre v1)  
**Referencia tests:** `test/IdentityRegistry.t.sol`, `test/RWAToken.transfer.t.sol`, `test/FreezePause.t.sol`, `test/ForcedTransfer.t.sol`, `test/DividendDistributor.t.sol`, `test/ModularCompliance.t.sol`, `test/fuzz/TransferLocks.t.sol`, `test/invariant/RWASolvency.invariant.t.sol`, `test/gas/`  
**Índice:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 32 |
| ⚠️ Informativo (diseño RWA / trust KYC / ops) | 4 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. El token usa **KYC obligatorio** (`IdentityNotVerified`), **pause/freeze** sin corromper supply, **`forcedTransfer`** gated por agent (`UnauthorizedAgent`), **compliance modular** (`TransferNotCompliant`), **dividendos** con CEI + `ReentrancyGuardTransient`, y pragma fijo **`0.8.24`**. Riesgos informativos: confianza en el issuer/agent on-chain, front-running de `approve`, dust de flooring en claims, y claims lab sin firmas criptográficas ONCHAINID de producción.

**Principios del suite / módulo 19 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `RWAErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + reentrancy en claim | ✅ `ReentrancyGuardTransient` |
| `isVerified` en transfer/transferFrom | ✅ `IdentityNotVerified` |
| Freeze/pause sin alterar `totalSupply` | ✅ + fuzz/invariantes |
| `forcedTransfer` solo agent | ✅ `UnauthorizedAgent` |
| Dividendos snapshot sin over-claim | ✅ |
| Compliance modular país / max balance | ✅ |
| Fuzz ≥ 1000 + invariantes | ✅ `foundry.toml` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en RWA tokenization |
|----|--------|--------|--------|-------------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; checks antes de restas (`frozenTokens`, balances); claims con floor |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) en todos los `.sol` |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | Stablecoin vía `SafeERC20`; sin ETH `.call` en v1 |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Sin custodia ETH; payouts ERC-20 |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `ReentrancyGuardTransient` + CEI en `DividendDistributor.claim`; hooks compliance post-`_update` |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `private` / `immutable` / `public` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | `safeTransfer` revierte si el payment token falla; estado de claim ya marcado (CEI) — recipient malicioso no reentra |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Front-running `approve` ERC-20 (RWA / USDC) — ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth vía `AccessControl` / `Ownable2Step`; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin lógica crítica basada en `block.timestamp` |
| SWC-117 | Signature Malleability | Parcial | ⚠️ | Claims lab sin ECDSA/EIP-712; confianza en owner de `Identity` — ver riesgos |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG on-chain |
| SWC-121 | Missing Protection against Signature Replay | Parcial | ✅ | Equivalente: claims one-shot por distribución (`AlreadyClaimed`); identities registradas por owner |
| SWC-122 | Lack of Proper Signature Verification | Parcial | ⚠️ | KYC lab = claim topic + trusted issuer mapping, no firma on-chain — ver riesgos |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + tests identity/freeze/forced/yield/compliance |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage arbitrario |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `ERC20, AccessControl, IRWAToken` / `Ownable2Step` en registries |
| SWC-126 | Insufficient Gas Griefing | Parcial | ✅ | Loops de módulos/topics O(N) con N pequeño (lab); claim O(1) |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | `isVerified` itera topics; `canTransfer` itera módulos — acotar en prod |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII en NatSpec/tests |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin variables muertas materiales |
| SWC-132 | Unexpected Ether balance | No | N/A | Contratos no esperan ETH |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | No | N/A | Sin `abi.encodePacked` de auth crítica multi-dynamic |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | Sin `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Hooks de módulos vacíos son intencionales (extensibilidad) |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | País / balances / claims públicos por diseño RWA permissioned |

---

## Riesgos informativos

### SWC-114 — Front-running de `approve`

**Descripción:** Un tercero puede frontrunear cambios de allowance sobre el RWA token o la stablecoin de dividendos (`depositPayment` / `transferFrom`).

**Estado:** ⚠️ Inherente a ERC-20.

**Mitigaciones:**
- Approvals mínimas al distributor; preferir flujos agent-gated.
- Tests de `transferFrom` y deposit con allowance.

### SWC-117 / SWC-122 — Claims KYC de laboratorio

**Descripción:** `Identity.addClaim` lo ejecuta el owner de la identidad; `isVerified` comprueba issuer ∈ `TrustedIssuersRegistry` y topics, **sin** verificación criptográfica de firma ONCHAINID de producción.

**Estado:** ⚠️ Diseño lab / trust en issuer + management key.

**Mitigaciones:**
- Topics + trusted issuers configurables por owner.
- Tests de issuer no confiable / topics incompletos → no verified.
- Post-v1: ONCHAINID completo con claim signatures.

### Dust de dividendos (SWC-101 residual)

**Descripción:** `claimable = balAt * total / supplyAt` floorea; la suma de claims puede ser `< totalAmount` (dust queda en el distributor).

**Estado:** ⚠️ Esperado; **no** permite over-claim.

**Mitigación:** Tests de dust + fuzz `sum(claims) ≤ total`; CEI evita double-claim.

### Trust en agent / compliance admin

**Descripción:** `AGENT_ROLE` puede freeze, pause, mint, burn y `forcedTransfer`. Owner de compliance puede añadir/quitar módulos y restringir países.

**Estado:** ⚠️ Diseño permissioned RWA (no DeFi permissionless).

**Mitigación:** `AccessControl` / `Ownable2Step`; tests `UnauthorizedAgent`; ops con multisig off-module en prod.

---

## Mapeo SWC → tests

| SWC | Test(s) relacionado(s) |
|-----|------------------------|
| SWC-101 | `DividendDistributor.t.sol` dust/fuzz; freeze arithmetic |
| SWC-103 | Compilador fijo (`forge build`) |
| SWC-107 | `claim` CEI + `ReentrancyGuardTransient` |
| SWC-114 | `transferFrom` / `depositPayment` approve paths |
| SWC-121 / auth | `ForcedTransfer.t.sol` UnauthorizedAgent; identity owner-only |
| SWC-122 / KYC | `IdentityRegistry.t.sol` untrusted issuer / incomplete topics |
| SWC-123 | Freeze/pause/compliance/forced error paths |
| SWC-128 | ModularCompliance modules loop (N=2 lab) |
| Solvencia | `fuzz/TransferLocks.t.sol`, `invariant/RWASolvency.invariant.t.sol` |

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-3643 / T-REX](https://gitlab.com/ERC-3643) (referencia de diseño educativa)
- [`18-liquid-staking-protocol/doc/SWC-AUDIT.md`](../../18-liquid-staking-protocol/doc/SWC-AUDIT.md)
- [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md)
