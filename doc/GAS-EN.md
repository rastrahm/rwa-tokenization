# Gas optimization — RWA Tokenization

> 🇪🇸 [Versión en español](./GAS-ES.md) · [Index](./README.md)

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract RWATokenGasTest --gas-report
forge snapshot --match-contract RWATokenGasTest
```

**Baseline date:** 2026-09-15 (SOLV phase / docs sync)  
**Snapshot:** `.gas-snapshot` (`test/gas/RWAToken.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`, EVM Cancun  
**Suite:** `forge test` → **80 PASS**

---

## Operation baseline (snapshot)

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_transfer` | **98 077** | KYC + compliance hooks (if bound) |
| `testGas_freezePartial` | **41 244** | Agent partial freeze |
| `testGas_forcedTransfer` | **116 855** | Freeze + forced recovery |
| `testGas_snapshotAndClaim` | **287 534** | snapshot + create + deposit + claim |

> The transfer gas test has **no** compliance bound (KYC only). With active modules the cost grows due to `canTransfer`, O(modules).

---

## Applied optimizations

| Technique | Where | Effect |
|-----------|-------|--------|
| Transient reentrancy (`tstore`) | `DividendDistributor` | No classic guard SSTORE |
| Custom errors | `RWAErrors` | vs `require` strings |
| CEI in claim | `DividendDistributor.claim` | State updated before `safeTransfer` |
| Lazy snapshots | `RWAToken` | No copying of all balances when a snapshot is taken |
| `immutable` registries | Identity / modules / distributor | Fewer SLOADs |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Hot-path inlining |

### Tradeoffs

- **`via_ir = true`:** fine for this module.
- **`isVerified` / `canTransfer`:** gas ∝ topics × modules; keep N small in the lab.
- **Post-`_update` hooks:** fixed cost per transfer when compliance is bound.

---

## References

- [`foundry.toml`](../foundry.toml)
- [`test/gas/RWAToken.gas.t.sol`](../test/gas/RWAToken.gas.t.sol)
- [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md)
