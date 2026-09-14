// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Token RWA permissioned (ERC-3643-like) con transfers gated por Identity Registry.
interface IRWAToken {
    /// @notice Identity Registry usado para `isVerified`.
    function identityRegistry() external view returns (address);

    /// @notice Actualiza el Identity Registry (solo admin).
    /// @param identityRegistry_ Nueva dirección del registry.
    function setIdentityRegistry(address identityRegistry_) external;

    /// @notice Emite tokens solo a una dirección verificada.
    /// @param to Destinatario KYC.
    /// @param amount Cantidad a mintear.
    function mint(address to, uint256 amount) external;

    /// @notice Quema tokens de una cuenta (solo agent).
    /// @param account Cuenta origen.
    /// @param amount Cantidad a quemar.
    function burn(address account, uint256 amount) external;

    /// @notice Indica si `account` tiene rol de agent.
    /// @param account Dirección a consultar.
    /// @return isAgent_ True si es agent.
    function isAgent(address account) external view returns (bool isAgent_);

    /// @notice True si el token está en pause global.
    function paused() external view returns (bool);

    /// @notice Pausa todas las transferencias entre wallets (solo agent).
    function pause() external;

    /// @notice Levanta el pause global (solo agent).
    function unpause() external;

    /// @notice True si la wallet está congelada por completo.
    /// @param account Dirección a consultar.
    function isFrozen(address account) external view returns (bool);

    /// @notice Cantidad de tokens congelados parcialmente en `account`.
    /// @param account Dirección a consultar.
    function getFrozenTokens(address account) external view returns (uint256);

    /// @notice Saldo libre (balance - frozenTokens) usable en transfers.
    /// @param account Dirección a consultar.
    function getFreeBalance(address account) external view returns (uint256);

    /// @notice Congela o descongela una wallet por completo (solo agent).
    /// @param account Wallet objetivo.
    /// @param freeze True para congelar.
    function setAddressFrozen(address account, bool freeze) external;

    /// @notice Congela parcialmente `amount` tokens (solo agent).
    /// @param account Wallet objetivo.
    /// @param amount Tokens a congelar.
    function freezePartialTokens(address account, uint256 amount) external;

    /// @notice Libera tokens parcialmente congelados (solo agent).
    /// @param account Wallet objetivo.
    /// @param amount Tokens a descongelar.
    function unfreezePartialTokens(address account, uint256 amount) external;
}
