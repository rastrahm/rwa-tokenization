// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IComplianceModule} from "../interfaces/ICompliance.sol";
import {RWAErrors} from "../errors/RWAErrors.sol";

/// @title MaxBalanceModule
/// @notice Limita el balance máximo que puede acumular un holder tras un mint/transfer.
contract MaxBalanceModule is IComplianceModule, Ownable2Step {
    address public immutable token;
    address public immutable override compliance;

    uint256 public maxBalance;

    event MaxBalanceSet(uint256 maxBalance);

    /// @param initialOwner Admin del módulo.
    /// @param token_ RWA token cuyas balances se consultan.
    /// @param compliance_ ModularCompliance autorizado a llamar hooks.
    /// @param maxBalance_ Cap inicial por wallet.
    constructor(address initialOwner, address token_, address compliance_, uint256 maxBalance_) Ownable(initialOwner) {
        if (token_ == address(0) || compliance_ == address(0)) revert RWAErrors.ZeroAddress();
        if (maxBalance_ == 0) revert RWAErrors.ZeroAmount();
        token = token_;
        compliance = compliance_;
        maxBalance = maxBalance_;
        emit MaxBalanceSet(maxBalance_);
    }

    modifier onlyCompliance() {
        if (msg.sender != compliance) revert RWAErrors.OnlyCompliance();
        _;
    }

    /// @notice Actualiza el cap de balance por wallet.
    /// @param maxBalance_ Nuevo máximo.
    function setMaxBalance(uint256 maxBalance_) external onlyOwner {
        if (maxBalance_ == 0) revert RWAErrors.ZeroAmount();
        maxBalance = maxBalance_;
        emit MaxBalanceSet(maxBalance_);
    }

    /// @inheritdoc IComplianceModule
    function canTransfer(address, address to, uint256 amount) external view returns (bool) {
        if (to == address(0)) return true;
        return IERC20(token).balanceOf(to) + amount <= maxBalance;
    }

    /// @inheritdoc IComplianceModule
    function transferred(address, address, uint256) external onlyCompliance {}

    /// @inheritdoc IComplianceModule
    function created(address, uint256) external onlyCompliance {}

    /// @inheritdoc IComplianceModule
    function destroyed(address, uint256) external onlyCompliance {}
}
