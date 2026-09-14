// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Identidad on-chain lab (estilo ONCHAINID mínimo) que almacena claims por topic.
interface IIdentity {
    /// @notice Añade o actualiza un claim emitido por `issuer` para `topic`.
    /// @param topic Claim topic (p. ej. KYC).
    /// @param issuer Emisor del claim.
    function addClaim(uint256 topic, address issuer) external;

    /// @notice Revoca el claim de un topic.
    /// @param topic Claim topic a eliminar.
    function removeClaim(uint256 topic) external;

    /// @notice Devuelve el emisor y validez del claim para un topic.
    /// @param topic Claim topic.
    /// @return issuer Emisor registrado (address(0) si no existe).
    /// @return valid True si el claim está activo.
    function getClaim(uint256 topic) external view returns (address issuer, bool valid);
}
