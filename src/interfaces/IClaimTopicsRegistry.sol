// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Topics de claims KYC/AML requeridos para verificación de identidad.
interface IClaimTopicsRegistry {
    /// @notice Añade un topic obligatorio para `isVerified`.
    /// @param claimTopic Identificador del claim (p. ej. 1 = KYC).
    function addClaimTopic(uint256 claimTopic) external;

    /// @notice Elimina un topic obligatorio.
    /// @param claimTopic Topic a eliminar.
    function removeClaimTopic(uint256 claimTopic) external;

    /// @notice Lista de topics requeridos.
    /// @return topics Array de claim topics.
    function getClaimTopics() external view returns (uint256[] memory topics);
}
