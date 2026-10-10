# Decisiones técnicas, lógica y gas — Módulo 19 RWA

> 🇬🇧 [English version](./DECISIONES-TECNICAS-EN.md) · [Índice](./README.md)

Documento de lectura para entender **qué se construyó**, **por qué** y **dónde se puede ahorrar gas**.  
Alineado al código v1 (Fases IDENT → SOLV · `forge test` → 80 PASS).

---

## 1. Qué problema resuelve

Un token RWA **no** puede comportarse como un ERC-20 abierto de DeFi:

| Necesidad | Solución en este módulo |
|-----------|-------------------------|
| Solo inversores KYC mueven tokens | `IdentityRegistry.isVerified` en cada transfer |
| Congelar wallets o el mercado | freeze total/parcial + pause global |
| Recuperar tokens de wallet perdida | `forcedTransfer` por agent |
| Reglas extras (país, tope de balance) | `ModularCompliance` + módulos |
| Repartir dividendos según holdings históricos | snapshots + `DividendDistributor` |

Stack: **Solidity `0.8.24` + Foundry + OpenZeppelin v5**.

---

## 2. Decisiones técnicas (y por qué)

### 2.1 Estándar de referencia: ERC-3643 / T-REX (lab, no fork byte-a-byte)

Se tomó el **modelo mental** de T-REX (identity + compliance + token permissioned + forced), no una copia 1:1 del repo oficial.

**Por qué:** el objetivo del módulo es entender y demostrar el flujo RWA con Foundry/TDD, no reempaquetar el ecosistema ONCHAINID de producción.

**Consecuencia:** API simplificada (`Identity` lab con `addClaim`, sin proxies upgradeables ni firmas criptográficas de claims).

---

### 2.2 Identidad: tres contratos + Identity por wallet

```
ClaimTopicsRegistry  →  qué claims son obligatorios (ej. KYC = 1)
TrustedIssuersRegistry → quién puede “emitir” esos claims
Identity               → claims de una persona (topic → issuer)
IdentityRegistry       → wallet → Identity + país; expone isVerified
```

**`isVerified(user)` es true si:**

1. La wallet tiene Identity registrada, y  
2. Para **cada** topic obligatorio hay un claim válido cuyo issuer es trusted **y** está autorizado para ese topic.  
3. Si no hay topics configurados → basta con estar registrado.

**Por qué separar registries:** en T-REX los topics y emisores cambian sin redeployar el token; el token solo pregunta `isVerified`.

**Tradeoff lab:** el owner de `Identity` escribe el claim on-chain. En producción ONCHAINID validaría firmas del claim issuer.

---

### 2.3 Token: OZ `ERC20` + `AccessControl` + override de `_update`

En OpenZeppelin v5, **toda** mint/burn/transfer pasa por `_update`. Ahí se centralizan los gates:

Orden en transfer normal:

1. ¿paused?  
2. ¿from/to frozen total?  
3. ¿`isVerified(from)` y `isVerified(to)`?  
4. ¿`amount ≤ balance - frozenTokens`?  
5. ¿compliance (si está bound) `canTransfer`?  
6. Actualizar snapshots lazy  
7. `super._update` (mover balances)  
8. Hook `compliance.transferred` / `created` / `destroyed`

**Por qué `_update` y no solo `transfer`:** cubre también `transferFrom` y mint/burn sin duplicar lógica.

**Roles:**

| Rol | Mecanismo | Qué hace |
|-----|-----------|----------|
| Admin | `DEFAULT_ADMIN_ROLE` | agents, set IR, set compliance |
| Agent | `AGENT_ROLE` | mint, burn, pause, freeze, snapshot, forced |
| Forced auth | check manual → `UnauthorizedAgent` | mensaje de error propio del módulo |

**Por qué AccessControl y no solo Ownable:** varios agents de compliance sin compartir una sola clave.

---

### 2.4 Freeze y pause **sin** tocar `totalSupply`

- **Pause:** bloquea solo transfers wallet↔wallet (mint de agent sigue OK).  
- **Freeze total:** la wallet no envía ni recibe.  
- **Freeze parcial:** `frozenTokens[user]`; spendable = `balance - frozenTokens`.

**Por qué no quemar al freeze:** el activo sigue existiendo legalmente; solo se restringe el movimiento (requisito típico RWA / .cursorrules).

Tras un **burn**, si `frozenTokens > balance`, se sincroniza a la baja (`_syncFrozenTokens`).

---

### 2.5 `forcedTransfer`: bypass selectivo

Recuperación legal / wallet comprometida:

| Check | ¿Se aplica? |
|-------|-------------|
| Agent | Sí (`UnauthorizedAgent`) |
| `isVerified(to)` | Sí (nueva wallet KYC) |
| `to` no frozen | Sí |
| Pause / freeze / KYC de `from` / `canTransfer` | **No** (flag `_forcedTransferInProgress`) |
| Hook `compliance.transferred` | Sí (si hay compliance) |

Si el amount supera el saldo libre, se **descongela** automáticamente la parte necesaria de `frozenTokens` del origen.

**Por qué el flag y no una función interna aparte:** reutiliza `_update` (snapshots + balances + hooks) sin pasar los gates de usuario.

---

### 2.6 Compliance modular (COMP)

```
RWAToken.setCompliance(ModularCompliance)
ModularCompliance.bindToken(token)  // una sola vez
ModularCompliance.addModule(CountryRestrictModule)
ModularCompliance.addModule(MaxBalanceModule)
```

- `canTransfer` = **AND** de todos los módulos.  
- Si `compliance == address(0)` → no hay reglas extra (útil en tests tempranos).  
- Hooks solo los puede llamar el token bound (`OnlyBoundToken`).

| Módulo | Regla |
|--------|--------|
| `CountryRestrictModule` | Bloquea si país de from/to está restringido (`investorCountry`) |
| `MaxBalanceModule` | `balanceOf(to) + amount ≤ maxBalance` (también en mint) |

**Por qué módulos separados:** añadir reglas sin redeployar el token (patrón T-REX).

---

### 2.7 Snapshots lazy (no OZ ERC20Snapshot)

OZ v5 **eliminó** `ERC20Snapshot`. Se reimplementó el patrón lazy:

1. `snapshot()` solo incrementa un id.  
2. En el **próximo** cambio de balance, se guarda el valor *antes* del cambio bajo ese id.  
3. `balanceOfAt` / `totalSupplyAt` hacen búsqueda binaria; si no hay entrada, usan el balance actual.

**Por qué lazy:** no hace falta iterar todos los holders al crear el snapshot (imposible on-chain de forma barata).

---

### 2.8 Dividendos: create → deposit → claim

```
snapshotId = token.snapshot()
createDistribution(USDC, totalAmount, snapshotId)  // guarda totalSupplyAt
depositPayment(id)                                 // transferFrom exacto totalAmount
claim(id)                                          // share = balAt * total / supplyAt
```

- Pro-rata con **floor** → puede quedar dust; **nunca** over-claim.  
- CEI + `ReentrancyGuardTransient` en `claim`.  
- Double-claim → `AlreadyClaimed`.

**Por qué snapshot y no balance actual:** quien vende después del corte no se lleva el dividendo del periodo.

---

### 2.9 Errores custom + pragma fijo

- `RWAErrors` library (sin `require("string")`).  
- `pragma solidity 0.8.24` exacto (suite + .cursorrules).  
- ETH: no hay custodia ETH; payouts con `SafeERC20`.

---

### 2.10 Fases por dominio (no 0–7 genérico)

IDENT → TOKEN → LOCK → FORCE → YIELD → COMP → SOLV, cada una autorizada antes de codear.

**Por qué:** el dominio RWA tiene piezas naturales (identidad, locks, recovery, yield, compliance); forzar “fase 0–7” de otros módulos no aportaba claridad.

---

## 3. Lógica que sigue el sistema (flujos)

### 3.1 Onboarding de un inversor

```
1. Deploy Identity(owner = inversor)
2. inversor.addClaim(TOPIC_KYC, claimIssuer)
3. issuer registry ya tiene claimIssuer como trusted para KYC
4. IdentityRegistry.registerIdentity(wallet, identity, country)
5. isVerified(wallet) == true
6. Agent mint(wallet, amount)
```

Sin el paso 4–5, cualquier transfer hacia/desde esa wallet revierte `IdentityNotVerified`.

---

### 3.2 Transfer normal entre dos KYC

```
Alice.transfer(Bob, X)
  → _update(Alice, Bob, X)
  → pause? freeze? KYC? free balance? compliance?
  → snapshot update (si hubo snapshot pendiente)
  → balances
  → compliance.transferred
```

---

### 3.3 Recovery forzada

```
Agent.forcedTransfer(walletPerdida, nuevaWalletKYC, X)
  → bypass pause/freeze/KYC(from)/canTransfer
  → exige KYC(to) y to no frozen
  → ajusta frozenTokens si hace falta
  → mueve tokens + hook transferred
```

---

### 3.4 Dividendo de un periodo

```
Agent.snapshot()
Owner.createDistribution(USDC, 10_000e6, snapId)
Owner.approve + depositPayment(distId)
Holder.claim(distId)  // pro-rata según balanceOfAt en snapId
```

Transfers **después** del snapshot no cambian el share de ese periodo.

---

### 3.5 Mapa mental de contratos

```
                    ┌─────────────────────┐
                    │  IdentityRegistry   │◄── isVerified / country
                    └──────────┬──────────┘
                               │
┌──────────────┐    ┌──────────▼──────────┐    ┌────────────────────┐
│ ClaimTopics  │    │      RWAToken       │───►│ ModularCompliance  │
│ TrustedIss.  │    │  ERC20+gates+snap   │    │  Country + MaxBal   │
└──────────────┘    └──────────┬──────────┘    └────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │ DividendDistributor │─── USDC (MockERC20)
                    └─────────────────────┘
```

---

## 4. Gas: estado actual y cómo mejorar

### 4.1 Baseline actual (`.gas-snapshot`)

| Path | Gas aprox. | Nota |
|------|------------|------|
| `transfer` (KYC, sin compliance bound en el gas test) | ~98 077 | Cada transfer = 2× `isVerified` (calls externos) |
| `freezePartial` | ~41 244 | Solo agent + storage |
| `forcedTransfer` | ~116 855 | Incluye freeze previo en el test |
| `snapshot + create + deposit + claim` | ~287 534 | Ciclo completo de yield |

Con **compliance bound** y 2 módulos, el transfer sube (loop `canTransfer` + hooks).

---

### 4.2 Lo que ya está bien (no tocar a ciegas)

| Técnica | Efecto |
|---------|--------|
| Custom errors | Reverts baratos |
| `immutable` en registries/módulos/distributor | Menos SLOAD |
| Snapshots lazy | No clona todos los balances |
| `ReentrancyGuardTransient` | Guard sin SSTORE clásico |
| `optimizer_runs = 10_000` + `via_ir` | Inlining |

---

### 4.3 Mejoras de gas realistas (por impacto)

Ordenadas de **más impacto / más natural** a **más invasivas**:

#### A. Cachear verificación KYC (alto impacto en transfer)

**Problema:** cada transfer hace `isVerified(from)` + `isVerified(to)`. Cada uno puede:

- leer topics (array en otro contrato),  
- llamar `Identity.getClaim` por topic,  
- consultar trusted issuers.

**Mejora:**  
- mapping `verified[user]` actualizado cuando se registra/borra identity o cambian topics/claims; o  
- short-circuit: si un solo topic KYC, función dedicada sin loop genérico.

**Tradeoff:** hay que invalidar el cache cuando cambian topics/issuers/claims (eventos + sync).

#### B. Storage packing en RWAToken (impacto medio)

Hoy: `bool _paused`, `bool _forcedTransferInProgress`, mappings separados.

**Mejora:** empaquetar flags en un `uint256` bitfield; o combinar `frozen` bool con lógica vía `frozenTokens == type(uint256).max` para freeze total (un solo slot de lectura en el hot path).

**Tradeoff:** legibilidad; hay que reescribir tests de freeze.

#### C. Evitar hook vacío en cada transfer (impacto medio-bajo)

`CountryRestrictModule` / `MaxBalanceModule` tienen `transferred`/`created`/`destroyed` vacíos, pero el token **siempre** llama al compliance y este itera módulos.

**Mejora:**  
- flag `hooksEnabled` en ModularCompliance, o  
- interfaz split: módulos “check-only” vs módulos con estado.

**Tradeoff:** menos extensibilidad “gratis” para módulos stateful.

#### D. `isVerified` sin arrays en memoria (impacto medio)

`getClaimTopics()` copia el array a memory en cada call.

**Mejora:** exponer `topicCount()` + `topicAt(i)` y leer uno a uno; o cachear hash/lista en IdentityRegistry.

#### E. Batch claim de dividendos (impacto en UX/gas del usuario)

Varios `claim(id)` = N txs.

**Mejora:** `claimMany(uint256[] ids)`.

**Tradeoff:** loops; cuidado con gas limit.

#### F. No llamar compliance en mint si MaxBalance puede vivir en el token (bajo / diseño)

Hoy mint también pasa por `canTransfer(0,to,amount)`.

**Mejora:** check de max balance inline en mint (un SLOAD) y dejar compliance solo para transfers.

**Tradeoff:** duplicar regla o acoplar MaxBalance al token.

#### G. Lo que **no** conviene “optimizar” aquí

- Quitar KYC del transfer → rompe el producto RWA.  
- Snapshots eager de todos los holders → imposible/costoso.  
- `unchecked` en claims sin cuidado → riesgo de over-claim.  
- Bajar `optimizer_runs` demasiado → code size vs runtime.

---

### 4.4 Heurística práctica

| Si el cuello de botella es… | Empieza por… |
|----------------------------|--------------|
| Transfer entre holders | Cache / simplificar `isVerified` |
| Transfer con muchos módulos | Reducir hooks vacíos; menos módulos en hot path |
| Claims de dividendos | `claimMany`; ya es barato el floor math |
| Deploy / wiring | Ya está ok para lab |

Medir siempre con:

```bash
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

---

## 5. Resumen en una frase por capa

| Capa | Decisión |
|------|----------|
| Identidad | Registries separados + `isVerified` como única pregunta del token |
| Token | Gates en `_update` + roles agent/admin |
| Locks | Freeze/pause sin alterar supply |
| Recovery | Forced bypassa reglas del origen, no las del destino |
| Compliance | Módulos enchufables; AND; opcional |
| Yield | Snapshot lazy + claim CEI pro-rata |
| Gas v1 | Correctness first; hot path caro por KYC externo (mejora natural: cache) |
| Proceso | Fases por dominio RWA con autorización |

---

## 6. Dónde seguir leyendo

| Doc | Qué aporta |
|------|------------|
| [planificacion-ES.md](./planificacion-ES.md) | Fases, árbol de archivos, checklist |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Decisiones por función |
| [flujograma-ES.md](./flujograma-ES.md) | Ciclo e2e |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | API / UML |
| [GAS-ES.md](./GAS-ES.md) | Baseline numérico |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Seguridad SWC-100–136 |

---

*Sync: 2026-09-15 · módulo v1 cerrado.*
