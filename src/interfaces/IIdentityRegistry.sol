// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Registro de identidades de inversores y verificación KYC (`isVerified`).
interface IIdentityRegistry {
    /// @notice True si el wallet tiene identidad y cubre todos los claim topics requeridos.
    /// @param userAddress Wallet del inversor.
    /// @return verified Resultado de la verificación.
    function isVerified(address userAddress) external view returns (bool verified);

    /// @notice Dirección del contrato de identidad ONCHAINID asociado al wallet.
    /// @param userAddress Wallet del inversor.
    /// @return identityAddress Contrato `IIdentity` o address(0).
    function identity(address userAddress) external view returns (address identityAddress);

    /// @notice Código de país ISO-3166 numérico del inversor.
    /// @param userAddress Wallet del inversor.
    /// @return country Código de país.
    function investorCountry(address userAddress) external view returns (uint16 country);

    /// @notice True si el wallet tiene identidad registrada.
    /// @param userAddress Wallet del inversor.
    /// @return registered True si existe registro.
    function contains(address userAddress) external view returns (bool registered);

    /// @notice Registra una identidad para un wallet.
    /// @param userAddress Wallet del inversor.
    /// @param identityAddress Contrato `IIdentity`.
    /// @param country Código de país.
    function registerIdentity(address userAddress, address identityAddress, uint16 country) external;

    /// @notice Elimina la identidad de un wallet.
    /// @param userAddress Wallet a dar de baja.
    function deleteIdentity(address userAddress) external;

    /// @notice Actualiza el contrato de identidad de un wallet ya registrado.
    /// @param userAddress Wallet del inversor.
    /// @param identityAddress Nueva identidad.
    function updateIdentity(address userAddress, address identityAddress) external;

    /// @notice Actualiza el país de un inversor registrado.
    /// @param userAddress Wallet del inversor.
    /// @param country Nuevo código de país.
    function updateCountry(address userAddress, uint16 country) external;

    /// @notice Registry de claim topics requeridos.
    function claimTopicsRegistry() external view returns (address);

    /// @notice Registry de emisores confiables.
    function trustedIssuersRegistry() external view returns (address);
}
