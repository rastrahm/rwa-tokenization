# Diagrama de clases — RWA Tokenization & Compliance Protocols

Vista estructural propuesta para el módulo 19 (ERC-3643 / T-REX + Identity Registry + yield).  
**Estado:** diseño previo a implementación · sync con `.cursorrules` local + suite.

> **Estándar de referencia:** token permissioned estilo ERC-3643 (T-REX): transferencias condicionadas a identidad verificada, compliance modular y recuperación forzosa por agente autorizado.

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IIdentityRegistry {
        <<interface>>
        +isVerified(userAddress) bool
        +identity(userAddress) address
        +investorCountry(userAddress) uint16
        +contains(userAddress) bool
        +registerIdentity(userAddress, identity, country)
        +deleteIdentity(userAddress)
        +updateIdentity(userAddress, identity)
        +updateCountry(userAddress, country)
    }

    class IClaimTopicsRegistry {
        <<interface>>
        +addClaimTopic(claimTopic)
        +removeClaimTopic(claimTopic)
        +getClaimTopics() uint256[]
    }

    class ITrustedIssuersRegistry {
        <<interface>>
        +addTrustedIssuer(trustedIssuer, claimTopics)
        +removeTrustedIssuer(trustedIssuer)
        +updateIssuerClaimTopics(trustedIssuer, claimTopics)
        +isTrustedIssuer(issuer) bool
        +getTrustedIssuers() address[]
        +getTrustedIssuerClaimTopics(trustedIssuer) uint256[]
    }

    class ICompliance {
        <<interface>>
        +canTransfer(from, to, amount) bool
        +transferred(from, to, amount)
        +created(to, amount)
        +destroyed(from, amount)
        +bindToken(token)
        +unbindToken(token)
    }

    class IRWAToken {
        <<interface>>
        +identityRegistry() address
        +compliance() address
        +isFrozen(account) bool
        +getFrozenTokens(account) uint256
        +pause()
        +unpause()
        +setAddressFrozen(account, freeze)
        +freezePartialTokens(account, amount)
        +unfreezePartialTokens(account, amount)
        +forcedTransfer(from, to, amount) bool
        +mint(to, amount)
        +burn(account, amount)
        +transfer(to, amount) bool
        +transferFrom(from, to, amount) bool
    }

    class IDividendDistributor {
        <<interface>>
        +createDistribution(paymentToken, totalAmount, snapshotId) uint256
        +claim(distributionId)
        +claimable(distributionId, account) uint256
        +hasClaimed(distributionId, account) bool
        +depositPayment(distributionId, amount)
    }

    class RWAErrors {
        <<errors>>
        +IdentityNotVerified()
        +TransferNotCompliant()
        +WalletFrozen()
        +InsufficientUnfrozenBalance()
        +TokenPaused()
        +UnauthorizedAgent()
        +ZeroAddress()
        +ZeroAmount()
        +AlreadyClaimed()
        +NothingToClaim()
        +InvalidSnapshot()
        +DistributionNotFunded()
        +InvalidCountry()
    }

    class IdentityRegistry {
        +tokenIdentity mapping
        +investorCountry mapping
        +claimTopicsRegistry IClaimTopicsRegistry
        +trustedIssuersRegistry ITrustedIssuersRegistry
        +isVerified(userAddress) bool
        +registerIdentity(userAddress, identity, country)
        +deleteIdentity(userAddress)
        +contains(userAddress) bool
    }

    class ModularCompliance {
        +tokenBound address
        +modules address[]
        +canTransfer(from, to, amount) bool
        +transferred(from, to, amount)
        +addModule(module)
        +removeModule(module)
    }

    class CountryRestrictModule {
        <<compliance module>>
        +restrictedCountries mapping
        +canTransfer(from, to, amount) bool
        +addCountryRestriction(country)
    }

    class MaxBalanceModule {
        <<compliance module>>
        +maxBalance uint256
        +canTransfer(from, to, amount) bool
    }

    class RWAToken {
        +identityRegistry IIdentityRegistry
        +compliance ICompliance
        +frozen mapping
        +frozenTokens mapping
        +agents mapping
        +paused bool
        +transfer(to, amount) bool
        +transferFrom(from, to, amount) bool
        +forcedTransfer(from, to, amount) bool
        +setAddressFrozen(account, freeze)
        +freezePartialTokens(account, amount)
        +pause()
        +unpause()
        +mint(to, amount)
        +burn(account, amount)
    }

    class DividendDistributor {
        +rwaToken IRWAToken
        +distributions mapping
        +claimed mapping
        +createDistribution(paymentToken, totalAmount, snapshotId) uint256
        +depositPayment(distributionId, amount)
        +claim(distributionId)
        +claimable(distributionId, account) uint256
    }

    class Distribution {
        <<struct>>
        +address paymentToken
        +uint256 totalAmount
        +uint256 snapshotId
        +uint256 totalSupplyAt
        +uint256 claimedAmount
        +bool funded
    }

    class MockERC20 {
        <<mock>>
        +mint(to, amount)
        +transfer(to, amount) bool
    }

    IIdentityRegistry <|.. IdentityRegistry
    ICompliance <|.. ModularCompliance
    IRWAToken <|.. RWAToken
    IDividendDistributor <|.. DividendDistributor
    IClaimTopicsRegistry <|.. ClaimTopicsRegistry
    ITrustedIssuersRegistry <|.. TrustedIssuersRegistry

    IdentityRegistry --> IClaimTopicsRegistry : topics KYC
    IdentityRegistry --> ITrustedIssuersRegistry : emisores
    ModularCompliance --> CountryRestrictModule : módulo
    ModularCompliance --> MaxBalanceModule : módulo
    RWAToken --> IIdentityRegistry : isVerified
    RWAToken --> ICompliance : canTransfer
    RWAToken ..> RWAErrors : IdentityNotVerified
    DividendDistributor --> IRWAToken : balanceOfAt / totalSupplyAt
    DividendDistributor --> Distribution : almacena
    DividendDistributor --> MockERC20 : USDC/USDT lab
```

## Responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `IdentityRegistry` | Registro de identidades ONCHAINID; `isVerified` exige claims de topics confiables |
| `ClaimTopicsRegistry` | Topics KYC/AML requeridos (p. ej. `KYC_CLAIM = 1`) |
| `TrustedIssuersRegistry` | Emisores de claims autorizados y topics que pueden firmar |
| `ModularCompliance` | Orquesta módulos (`canTransfer` + hooks post-transfer) |
| `RWAToken` | ERC-20 permissioned: transfer gated + freeze + pause + `forcedTransfer` |
| `DividendDistributor` | Distribuciones pro-rata por snapshot; claim de USDC/USDT |
| `RWAErrors` | Custom errors del módulo (`IdentityNotVerified` obligatorio) |

## Modelo de permisos en transferencia

```
  transfer / transferFrom
           │
           ▼
  ┌────────────────────┐
  │ ¿paused?           │──sí──► TokenPaused
  └─────────┬──────────┘
            │ no
            ▼
  ┌────────────────────┐
  │ ¿from/to frozen?   │──sí──► WalletFrozen
  └─────────┬──────────┘
            │ no
            ▼
  ┌────────────────────┐
  │ IdentityRegistry   │
  │ isVerified(from)   │──no──► IdentityNotVerified
  │ isVerified(to)     │──no──► IdentityNotVerified
  └─────────┬──────────┘
            │ sí
            ▼
  ┌────────────────────┐
  │ Compliance         │──no──► TransferNotCompliant
  │ canTransfer(...)   │
  └─────────┬──────────┘
            │ sí
            ▼
      _update balances
      compliance.transferred(...)
```

## Errores custom (diseño)

| Error | Uso |
|-------|-----|
| `IdentityNotVerified()` | `transfer` / `transferFrom` sin KYC en from o to |
| `TransferNotCompliant()` | Módulo de compliance rechaza el movimiento |
| `WalletFrozen()` | Dirección congelada total |
| `InsufficientUnfrozenBalance()` | Freeze parcial deja saldo libre insuficiente |
| `TokenPaused()` | Pause global activo |
| `UnauthorizedAgent()` | Caller no es agent/compliance manager |
| `AlreadyClaimed()` / `NothingToClaim()` | Ciclo de dividendos |
| `InvalidSnapshot()` / `DistributionNotFunded()` | Distribución mal formada o sin fondeo |
