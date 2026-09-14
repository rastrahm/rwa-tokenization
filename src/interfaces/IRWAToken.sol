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
    /// @return isAgent True si es agent.
    function isAgent(address account) external view returns (bool isAgent);
}
