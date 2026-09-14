// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDividendDistributor} from "./interfaces/IDividendDistributor.sol";
import {IRWAToken} from "./interfaces/IRWAToken.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title DividendDistributor
/// @notice Distribuye USDC/USDT pro-rata según holdings en un snapshot del RWA token.
contract DividendDistributor is IDividendDistributor, Ownable2Step, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    struct Distribution {
        address paymentToken;
        uint256 totalAmount;
        uint256 snapshotId;
        uint256 totalSupplyAt;
        uint256 claimedAmount;
        bool funded;
    }

    IRWAToken private immutable _rwaToken;

    uint256 private _distributionCount;
    mapping(uint256 id => Distribution) private _distributions;
    mapping(uint256 id => mapping(address account => bool claimed)) private _claimed;

    event DistributionCreated(
        uint256 indexed distributionId,
        address indexed paymentToken,
        uint256 totalAmount,
        uint256 snapshotId,
        uint256 totalSupplyAt
    );
    event DistributionFunded(uint256 indexed distributionId, uint256 amount);
    event Claimed(uint256 indexed distributionId, address indexed account, uint256 amount);

    /// @param initialOwner Issuer / dividend manager.
    /// @param rwaToken_ Token RWA con snapshots.
    constructor(address initialOwner, address rwaToken_) Ownable(initialOwner) {
        if (rwaToken_ == address(0)) revert RWAErrors.ZeroAddress();
        _rwaToken = IRWAToken(rwaToken_);
    }

    /// @inheritdoc IDividendDistributor
    function rwaToken() external view returns (address) {
        return address(_rwaToken);
    }

    /// @inheritdoc IDividendDistributor
    function distributionCount() external view returns (uint256) {
        return _distributionCount;
    }

    /// @notice Datos de una distribución.
    function getDistribution(uint256 distributionId)
        external
        view
        returns (
            address paymentToken,
            uint256 totalAmount,
            uint256 snapshotId,
            uint256 totalSupplyAt,
            uint256 claimedAmount,
            bool funded
        )
    {
        Distribution storage d = _requireDistribution(distributionId);
        return (d.paymentToken, d.totalAmount, d.snapshotId, d.totalSupplyAt, d.claimedAmount, d.funded);
    }

    /// @inheritdoc IDividendDistributor
    function createDistribution(address paymentToken, uint256 totalAmount, uint256 snapshotId)
        external
        onlyOwner
        returns (uint256 distributionId)
    {
        if (paymentToken == address(0)) revert RWAErrors.ZeroAddress();
        if (totalAmount == 0) revert RWAErrors.ZeroAmount();

        uint256 supplyAt = _rwaToken.totalSupplyAt(snapshotId);
        if (supplyAt == 0) revert RWAErrors.InvalidSnapshot();

        distributionId = ++_distributionCount;
        _distributions[distributionId] = Distribution({
            paymentToken: paymentToken,
            totalAmount: totalAmount,
            snapshotId: snapshotId,
            totalSupplyAt: supplyAt,
            claimedAmount: 0,
            funded: false
        });

        emit DistributionCreated(distributionId, paymentToken, totalAmount, snapshotId, supplyAt);
    }

    /// @inheritdoc IDividendDistributor
    function depositPayment(uint256 distributionId) external onlyOwner {
        Distribution storage d = _requireDistribution(distributionId);
        if (d.funded) revert RWAErrors.AlreadyFunded();

        IERC20(d.paymentToken).safeTransferFrom(msg.sender, address(this), d.totalAmount);
        d.funded = true;
        emit DistributionFunded(distributionId, d.totalAmount);
    }

    /// @inheritdoc IDividendDistributor
    function claimable(uint256 distributionId, address account) public view returns (uint256) {
        Distribution storage d = _requireDistribution(distributionId);
        if (_claimed[distributionId][account]) return 0;
        uint256 balAt = _rwaToken.balanceOfAt(account, d.snapshotId);
        if (balAt == 0 || d.totalSupplyAt == 0) return 0;
        return (balAt * d.totalAmount) / d.totalSupplyAt;
    }

    /// @inheritdoc IDividendDistributor
    function hasClaimed(uint256 distributionId, address account) external view returns (bool) {
        return _claimed[distributionId][account];
    }

    /// @inheritdoc IDividendDistributor
    function claim(uint256 distributionId) external nonReentrant {
        Distribution storage d = _requireDistribution(distributionId);
        if (!d.funded) revert RWAErrors.DistributionNotFunded();
        if (_claimed[distributionId][msg.sender]) revert RWAErrors.AlreadyClaimed();

        uint256 amount = claimable(distributionId, msg.sender);
        if (amount == 0) revert RWAErrors.NothingToClaim();

        // CEI
        _claimed[distributionId][msg.sender] = true;
        d.claimedAmount += amount;
        IERC20(d.paymentToken).safeTransfer(msg.sender, amount);

        emit Claimed(distributionId, msg.sender, amount);
    }

    function _requireDistribution(uint256 distributionId) private view returns (Distribution storage d) {
        if (distributionId == 0 || distributionId > _distributionCount) revert RWAErrors.InvalidDistribution();
        d = _distributions[distributionId];
    }
}
