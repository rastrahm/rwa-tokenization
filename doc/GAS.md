# Optimización de gas — RWA Tokenization

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

**Fecha baseline:** 2026-09-14 (Fase SOLV)  
**Snapshot:** `.gas-snapshot` (`test/gas/RWAToken.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`, EVM Cancun  
**Suite:** `forge test` → **80 PASS**

---

## Baseline operaciones (snapshot)

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_transfer` | **98 077** | KYC + compliance hooks (si bound) |
| `testGas_freezePartial` | **41 244** | Agent freeze parcial |
| `testGas_forcedTransfer` | **116 855** | Freeze + forced recovery |
| `testGas_snapshotAndClaim` | **287 534** | snapshot + create + deposit + claim |

> En el gas test de transfer **no** hay compliance bound (solo KYC). Con módulos activos el costo sube por `canTransfer` O(módulos).

---

## Optimizaciones aplicadas

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| Transient reentrancy (`tstore`) | `DividendDistributor` | Sin SSTORE del guard clásico |
| Custom errors | `RWAErrors` | vs `require` strings |
| CEI en claim | `DividendDistributor.claim` | Estado antes de `safeTransfer` |
| Snapshots lazy | `RWAToken` | Sin copiar todos los balances al crear snapshot |
| `immutable` registries | Identity / modules / distributor | Menos SLOAD |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining hot paths |

### Tradeoffs

- **`via_ir = true`:** OK en este módulo.
- **`isVerified` / `canTransfer`:** gas ∝ topics × módulos; mantener N pequeño en lab.
- **Hooks post-`_update`:** coste fijo por transfer cuando hay compliance bound.

---

## Referencias

- [`foundry.toml`](../foundry.toml)
- [`test/gas/RWAToken.gas.t.sol`](../test/gas/RWAToken.gas.t.sol)
- [SWC-AUDIT.md](./SWC-AUDIT.md)
