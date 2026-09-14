# Planificación — Módulo 19: RWA Tokenization & Compliance Protocols

**Estado:** documentación inicial · **ninguna fase de código autorizada**.  
**Regla de avance:** no se escribe código de una fase hasta tu autorización explícita (`Autorizo Fase <ID>`).  
**Nota de diseño:** las fases **no** siguen el esquema genérico 0–7 de módulos anteriores; se organizan por **dominios de compliance RWA**.

---

## 1. Objetivo

Construir un sistema de **tokenización de activos reales (RWA)** permissioned que permita:

- Emitir un token **ERC-20 restringido** alineado a **ERC-3643 / T-REX**.
- Verificar identidades vía **Identity Registry** (ONCHAINID / claims) antes de cualquier `transfer` / `transferFrom`.
- Aplicar **compliance modular** (país, max balance, etc.) sin romper la contabilidad de supply.
- Congelar wallets (**freeze total/parcial**) y **pausar** el token globalmente.
- Ejecutar **forced transfers** por agente autorizado (recuperación legal / wallet perdida).
- Distribuir **dividendos pro-rata** (USDC/USDT) según holdings en **snapshot**.

Stack: **Foundry + Solidity `0.8.24`**. Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `IdentityRegistry` + `isVerified` | ONCHAINID completo con proxies upgradeables de producción |
| `ClaimTopicsRegistry` + `TrustedIssuersRegistry` (lab) | Integración real con emisores KYC off-chain |
| `RWAToken` permissioned (ERC-3643-like) | Secondary market / DEX listing compliance |
| `ModularCompliance` + ≥2 módulos (país, max balance) | Motor de reglas off-chain / ZK-KYC |
| Freeze total, freeze parcial, pause global | Time-locks de gobernanza multi-sig |
| `forcedTransfer` por agent | Court oracle automatizado |
| `DividendDistributor` snapshot + claim USDC/USDT | Streaming yield / rebase del RWA token |
| Tests: compliance fail, yield accuracy, recovery, fuzz locks | Frontend Next.js (App Router) |
| `Deploy.s.sol` + gas snapshot + SWC-AUDIT | Mainnet issuance legal packaging |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (`AccessControl` / `Ownable2Step`, `ERC20`, `ReentrancyGuard`, snapshots o equivalente).
- Foundry: unit + fuzz (`runs >= 1000`) + invariant + gas.
- **Custom errors** (no `require` strings).
- CEI estricto; tokens externos vía `safeTransfer` / checks de retorno.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests primero en cada fase de contratos.

### Módulo 19 (`.cursorrules` local)

- Todo `transfer` / `transferFrom` → `isVerified` → `error IdentityNotVerified()`.
- Agent/compliance manager → `forcedTransfer` para recovery.
- Dividendos snapshot / pro-rata en USDC/USDT.
- Freeze individual + pause global **sin** corromper `totalSupply`.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI: registro (vista), transfer gated, claim dividendos, panel agent.
- App Router, Zod, Vitest + RTL, JSDoc, sin `any`.
- **Fuera** de las fases de esta planificación.

---

## 4. Arquitectura objetivo (v1)

```
19-rwa-tokenization/
├── README.md
├── .cursorrules
├── .gitignore
├── .env.example
├── foundry.toml
├── remappings.txt
├── doc/
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── src/
│   ├── RWAToken.sol
│   ├── IdentityRegistry.sol
│   ├── ClaimTopicsRegistry.sol
│   ├── TrustedIssuersRegistry.sol
│   ├── ModularCompliance.sol
│   ├── DividendDistributor.sol
│   ├── interfaces/
│   ├── compliance/
│   │   ├── CountryRestrictModule.sol
│   │   └── MaxBalanceModule.sol
│   ├── errors/
│   │   └── RWAErrors.sol
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── IdentityRegistry.t.sol
│   ├── RWAToken.transfer.t.sol
│   ├── FreezePause.t.sol
│   ├── ForcedTransfer.t.sol
│   ├── DividendDistributor.t.sol
│   ├── fuzz/
│   └── invariant/
└── script/
    └── Deploy.s.sol
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `IdentityRegistry` | Alta/baja de identidades; `isVerified` |
| `ClaimTopicsRegistry` | Topics KYC requeridos |
| `TrustedIssuersRegistry` | Emisores de claims confiables |
| `ModularCompliance` | Agrega módulos `canTransfer` |
| `RWAToken` | ERC-20 permissioned + freeze + pause + forced |
| `DividendDistributor` | Snapshot → claim stablecoin pro-rata |
| `MockERC20` | USDC/USDT de lab |

---

## 5. Errores custom (módulo)

```solidity
error IdentityNotVerified();       // obligatorio (.cursorrules)
error TransferNotCompliant();
error WalletFrozen();
error InsufficientUnfrozenBalance();
error TokenPaused();
error UnauthorizedAgent();
error ZeroAddress();
error ZeroAmount();
error AlreadyClaimed();
error NothingToClaim();
error InvalidSnapshot();
error DistributionNotFunded();
error InvalidCountry();
```

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“Autorizo Fase \<ID\>”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |
| **IDs** | Fases con nombres de dominio RWA (no numeración 0–7 genérica). |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| **IDENT** | Scaffold Foundry + Identity Registry (`isVerified`) | ⏳ Pendiente | ❌ Sin autorizar |
| **TOKEN** | `RWAToken` permissioned (transfer gated ERC-3643) | ⏳ Pendiente | ❌ Sin autorizar |
| **LOCK** | Pause global + freeze total/parcial | ⏳ Pendiente | ❌ Sin autorizar |
| **FORCE** | Agent `forcedTransfer` / asset recovery | ⏳ Pendiente | ❌ Sin autorizar |
| **YIELD** | `DividendDistributor` snapshot USDC/USDT | ⏳ Pendiente | ❌ Sin autorizar |
| **COMP** | `ModularCompliance` + módulos país / max balance | ⏳ Pendiente | ❌ Sin autorizar |
| **SOLV** | Suite: compliance fail, yield accuracy, recovery, fuzz locks + Deploy/gas | ⏳ Pendiente | ❌ Sin autorizar |

**Cómo autorizar:** responde en el chat con `Autorizo Fase IDENT` (o el ID que corresponda). Puedes autorizar de a una; el orden recomendado es el del tablero.

---

## 7. Detalle por fase

### Fase IDENT — Scaffold + Identity Registry

**Objetivo:** repo Foundry compilable e identidad on-chain con `isVerified` confiable.

1. Scaffold: `foundry.toml` (solc `0.8.24`, fuzz `runs >= 1000`), OZ v5, carpetas `src/`, `test/`, `script/`.
2. `RWAErrors.sol` con `IdentityNotVerified` y errores base.
3. `ClaimTopicsRegistry` + `TrustedIssuersRegistry` (lab mínimo).
4. `IdentityRegistry`: `registerIdentity`, `deleteIdentity`, `isVerified`.
5. TDD: verificado vs no verificado; topics incompletos → `false`.

**Criterio de salida:** `forge build` + tests de identity en verde.

**Depende de:** nada (primera fase de código).

---

### Fase TOKEN — RWAToken permissioned

**Objetivo:** ERC-20 cuyas transferencias exigen KYC en `from` y `to`.

1. TDD primero: transfer entre no-KYC → `IdentityNotVerified`; KYC↔KYC OK.
2. `RWAToken` + binding a `IdentityRegistry`.
3. `mint` solo a verificados; `transfer` / `transferFrom` con check obligatorio.
4. Roles agent/owner vía `AccessControl` o `Ownable2Step`.

**Criterio de salida:** suite de transfer compliance-failure en verde.

**Depende de:** IDENT.

---

### Fase LOCK — Pause y freeze modular

**Objetivo:** restringir movimiento sin alterar `totalSupply`.

1. TDD: pause bloquea transfers; freeze total; freeze parcial deja saldo libre usable.
2. `pause` / `unpause`, `setAddressFrozen`, `freezePartialTokens` / `unfreezePartialTokens`.
3. Contabilidad: `balance - frozenTokens` como spendable.
4. Solo agents.

**Criterio de salida:** tests de freeze/pause + invariante supply intacto.

**Depende de:** TOKEN.

---

### Fase FORCE — Forced transfer / recovery

**Objetivo:** agente recupera tokens hacia una identidad verificada nueva.

1. TDD: agent mueve desde wallet frozen/perdida → nueva KYC; non-agent revierte `UnauthorizedAgent`.
2. Destino debe pasar `isVerified`.
3. Ajuste de `frozenTokens` si aplica; eventos `ForcedTransfer`.
4. Bypass de reglas de freeze del `from` (recuperación legal), manteniendo checks del `to`.

**Criterio de salida:** forced recovery tests en verde.

**Depende de:** LOCK.

---

### Fase YIELD — DividendDistributor

**Objetivo:** holders claim USDC/USDT pro-rata según snapshot histórico.

1. TDD: 2–3 inversores con proporciones distintas; suma de claims ≤ total; sin double-claim.
2. Snapshot del RWA token (OZ `ERC20Snapshot` / checkpoints v5 equivalente).
3. `createDistribution` → `depositPayment` → `claim`.
4. CEI + `ReentrancyGuard` en claim.

**Criterio de salida:** yield claim accuracy tests (sin dust abusivo / excess claim).

**Depende de:** TOKEN (snapshot del token; puede paralelizarse tras TOKEN si LOCK/FORCE aún no autorizados — **solo si lo indicas**).

---

### Fase COMP — ModularCompliance

**Objetivo:** reglas componibles además del KYC base.

1. `ModularCompliance.bindToken` + modules array.
2. Módulos v1: `CountryRestrictModule`, `MaxBalanceModule`.
3. `RWAToken.transfer` consulta `canTransfer` tras `isVerified`.
4. TDD: país restringido / max balance excedido → `TransferNotCompliant`.

**Criterio de salida:** tests por módulo + combinación KYC+compliance.

**Depende de:** TOKEN (recomendado tras LOCK para no mezclar freeze con reglas de país en el mismo PR mental).

---

### Fase SOLV — Hardening, fuzz, deploy y cierre v1

**Objetivo:** demostrar solvencia bajo freezes parciales y reglas cambiantes; cerrar lab.

1. Fuzz: freeze parcial aleatorio + updates de compliance; supply y balances coherentes.
2. Invariantes: `Σ balances == totalSupply`; frozen ≤ balance; claims ≤ distribution.
3. `Deploy.s.sol`, `.env.example`, NatSpec completo, gas snapshot.
4. `doc/SWC-AUDIT.md` + `doc/GAS.md` + sync de diagramas si hubo desviaciones.
5. Marcar fases ✅ en este documento.

**Criterio de salida:** `forge test` (unit + fuzz + invariant) verde; deploy local OK.

**Depende de:** IDENT + TOKEN + LOCK + FORCE + YIELD + COMP.

---

## 8. Checklist de aceptación global (v1)

- [ ] Todo `transfer` / `transferFrom` llama `isVerified` → `IdentityNotVerified`
- [ ] Freeze total/parcial y pause sin corromper `totalSupply`
- [ ] Agent puede `forcedTransfer` a identidad verificada
- [ ] Dividendos snapshot: proporciones correctas, sin over-claim
- [ ] Compliance modular rechaza transfers no conformes
- [ ] Fuzz de locks + invariantes de solvencia en verde
- [ ] CEI + custom errors + NatSpec + solc `0.8.24`
- [ ] Frontend Next.js **no** incluido (post-v1)

---

## 9. Próximo paso

**Esperando tu autorización.**  
Respuesta sugerida para arrancar:

`Autorizo Fase IDENT`
