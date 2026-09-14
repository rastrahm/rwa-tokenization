// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Motor de compliance modular (ERC-3643 / T-REX style).
interface ICompliance {
    /// @notice True si la transferencia cumple todos los módulos.
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /// @notice Hook post-transfer entre wallets.
    function transferred(address from, address to, uint256 amount) external;

    /// @notice Hook post-mint.
    function created(address to, uint256 amount) external;

    /// @notice Hook post-burn.
    function destroyed(address from, uint256 amount) external;

    /// @notice Vincula el token RWA (una sola vez).
    function bindToken(address token) external;

    /// @notice Token vinculado.
    function tokenBound() external view returns (address);
}

/// @notice Módulo individual de reglas de compliance.
interface IComplianceModule {
    /// @notice Evalúa si el movimiento es conforme.
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /// @notice Hook post-transfer (opcional para estado del módulo).
    function transferred(address from, address to, uint256 amount) external;

    /// @notice Hook post-mint.
    function created(address to, uint256 amount) external;

    /// @notice Hook post-burn.
    function destroyed(address from, uint256 amount) external;

    /// @notice Compliance que puede invocar los hooks.
    function compliance() external view returns (address);
}
