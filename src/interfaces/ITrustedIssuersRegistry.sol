// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Registro de emisores de claims confiables y topics que pueden firmar.
interface ITrustedIssuersRegistry {
    /// @notice Registra un emisor confiable con los topics que puede emitir.
    /// @param trustedIssuer Dirección del emisor.
    /// @param claimTopics Topics autorizados para ese emisor.
    function addTrustedIssuer(address trustedIssuer, uint256[] calldata claimTopics) external;

    /// @notice Elimina un emisor confiable.
    /// @param trustedIssuer Emisor a eliminar.
    function removeTrustedIssuer(address trustedIssuer) external;

    /// @notice Actualiza los topics permitidos de un emisor.
    /// @param trustedIssuer Emisor existente.
    /// @param claimTopics Nuevos topics.
    function updateIssuerClaimTopics(address trustedIssuer, uint256[] calldata claimTopics) external;

    /// @notice Indica si la dirección es emisor confiable.
    /// @param issuer Dirección a consultar.
    /// @return trusted True si está registrado.
    function isTrustedIssuer(address issuer) external view returns (bool trusted);

    /// @notice Indica si el emisor puede emitir el topic dado.
    /// @param issuer Emisor confiable.
    /// @param claimTopic Topic a comprobar.
    /// @return allowed True si el topic está autorizado.
    function hasClaimTopic(address issuer, uint256 claimTopic) external view returns (bool allowed);

    /// @notice Lista de emisores confiables.
    /// @return issuers Array de direcciones.
    function getTrustedIssuers() external view returns (address[] memory issuers);

    /// @notice Topics autorizados de un emisor.
    /// @param trustedIssuer Emisor a consultar.
    /// @return claimTopics Array de topics.
    function getTrustedIssuerClaimTopics(address trustedIssuer)
        external
        view
        returns (uint256[] memory claimTopics);
}
