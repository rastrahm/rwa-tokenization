// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Distribución pro-rata de dividendos (USDC/USDT) según snapshot del RWA token.
interface IDividendDistributor {
    /// @notice Token RWA sobre el que se toman los snapshots.
    function rwaToken() external view returns (address);

    /// @notice Crea una distribución pendiente de fondeo.
    /// @param paymentToken Stablecoin de pago (USDC/USDT lab).
    /// @param totalAmount Monto total a repartir.
    /// @param snapshotId Snapshot del RWA token.
    /// @return distributionId Id de la distribución.
    function createDistribution(address paymentToken, uint256 totalAmount, uint256 snapshotId)
        external
        returns (uint256 distributionId);

    /// @notice Transfiere `totalAmount` del payment token al distributor y marca funded.
    /// @param distributionId Id de la distribución.
    function depositPayment(uint256 distributionId) external;

    /// @notice Claim del share pro-rata del caller.
    /// @param distributionId Id de la distribución.
    function claim(uint256 distributionId) external;

    /// @notice Monto claimable para `account` (0 si ya claimed o sin balance en snapshot).
    function claimable(uint256 distributionId, address account) external view returns (uint256);

    /// @notice True si `account` ya reclamó la distribución.
    function hasClaimed(uint256 distributionId, address account) external view returns (bool);

    /// @notice Número de distribuciones creadas.
    function distributionCount() external view returns (uint256);
}
