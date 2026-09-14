// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {IRWAToken} from "./interfaces/IRWAToken.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title RWAToken
/// @notice ERC-20 permissioned: `transfer` / `transferFrom` / `mint` exigen `IdentityRegistry.isVerified`.
/// @dev Freeze, pause, forcedTransfer y compliance modular se añaden en fases LOCK / FORCE / COMP.
contract RWAToken is ERC20, AccessControl, IRWAToken {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IIdentityRegistry private _identityRegistry;

    event IdentityRegistrySet(address indexed identityRegistry);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    /// @param name_ Nombre del token.
    /// @param symbol_ Símbolo del token.
    /// @param admin Admin (`DEFAULT_ADMIN_ROLE`) y primer agent.
    /// @param identityRegistry_ Registry de identidades KYC.
    constructor(string memory name_, string memory symbol_, address admin, address identityRegistry_)
        ERC20(name_, symbol_)
    {
        if (admin == address(0) || identityRegistry_ == address(0)) revert RWAErrors.ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        emit IdentityRegistrySet(identityRegistry_);
        emit AgentAdded(admin);
    }

    /// @inheritdoc IRWAToken
    function identityRegistry() external view returns (address) {
        return address(_identityRegistry);
    }

    /// @inheritdoc IRWAToken
    function setIdentityRegistry(address identityRegistry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (identityRegistry_ == address(0)) revert RWAErrors.ZeroAddress();
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        emit IdentityRegistrySet(identityRegistry_);
    }

    /// @inheritdoc IRWAToken
    function isAgent(address account) external view returns (bool) {
        return hasRole(AGENT_ROLE, account);
    }

    /// @notice Otorga rol de agent (mint/burn y futuras acciones de compliance).
    /// @param agent Dirección a autorizar.
    function addAgent(address agent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (agent == address(0)) revert RWAErrors.ZeroAddress();
        _grantRole(AGENT_ROLE, agent);
        emit AgentAdded(agent);
    }

    /// @notice Revoca rol de agent.
    /// @param agent Dirección a revocar.
    function removeAgent(address agent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(AGENT_ROLE, agent);
        emit AgentRemoved(agent);
    }

    /// @inheritdoc IRWAToken
    function mint(address to, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (amount == 0) revert RWAErrors.ZeroAmount();
        if (!_identityRegistry.isVerified(to)) revert RWAErrors.IdentityNotVerified();
        _mint(to, amount);
    }

    /// @inheritdoc IRWAToken
    function burn(address account, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (amount == 0) revert RWAErrors.ZeroAmount();
        _burn(account, amount);
    }

    /// @dev Gate KYC en transfers entre wallets. Mint/burn no exigen `from`/`to` verificados aquí
    ///      (mint ya valida `to` en `mint`; burn es acción de agent).
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) {
            if (!_identityRegistry.isVerified(from) || !_identityRegistry.isVerified(to)) {
                revert RWAErrors.IdentityNotVerified();
            }
        }
        super._update(from, to, value);
    }
}
