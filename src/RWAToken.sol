// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {IRWAToken} from "./interfaces/IRWAToken.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title RWAToken
/// @notice ERC-20 permissioned: KYC en transfers, pause global y freeze total/parcial.
/// @dev `forcedTransfer` y compliance modular se añaden en fases FORCE / COMP.
contract RWAToken is ERC20, AccessControl, IRWAToken {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IIdentityRegistry private _identityRegistry;

    bool private _paused;
    mapping(address account => bool frozen) private _frozen;
    mapping(address account => uint256 amount) private _frozenTokens;

    event IdentityRegistrySet(address indexed identityRegistry);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event AddressFrozen(address indexed account, bool indexed isFrozen, address indexed agent);
    event TokensFrozen(address indexed account, uint256 amount);
    event TokensUnfrozen(address indexed account, uint256 amount);

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

    /// @notice Otorga rol de agent (mint/burn/freeze/pause y futuras acciones de compliance).
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
    function paused() external view returns (bool) {
        return _paused;
    }

    /// @inheritdoc IRWAToken
    function pause() external onlyRole(AGENT_ROLE) {
        if (_paused) revert RWAErrors.TokenPaused();
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IRWAToken
    function unpause() external onlyRole(AGENT_ROLE) {
        if (!_paused) revert RWAErrors.TokenNotPaused();
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IRWAToken
    function isFrozen(address account) external view returns (bool) {
        return _frozen[account];
    }

    /// @inheritdoc IRWAToken
    function getFrozenTokens(address account) external view returns (uint256) {
        return _frozenTokens[account];
    }

    /// @inheritdoc IRWAToken
    function getFreeBalance(address account) public view returns (uint256) {
        uint256 bal = balanceOf(account);
        uint256 frozenAmt = _frozenTokens[account];
        return bal > frozenAmt ? bal - frozenAmt : 0;
    }

    /// @inheritdoc IRWAToken
    function setAddressFrozen(address account, bool freeze) external onlyRole(AGENT_ROLE) {
        if (account == address(0)) revert RWAErrors.ZeroAddress();
        _frozen[account] = freeze;
        emit AddressFrozen(account, freeze, msg.sender);
    }

    /// @inheritdoc IRWAToken
    function freezePartialTokens(address account, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (account == address(0)) revert RWAErrors.ZeroAddress();
        if (amount == 0) revert RWAErrors.ZeroAmount();
        uint256 free = getFreeBalance(account);
        if (free < amount) revert RWAErrors.InsufficientUnfrozenBalance();
        _frozenTokens[account] += amount;
        emit TokensFrozen(account, amount);
    }

    /// @inheritdoc IRWAToken
    function unfreezePartialTokens(address account, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (account == address(0)) revert RWAErrors.ZeroAddress();
        if (amount == 0) revert RWAErrors.ZeroAmount();
        uint256 frozenAmt = _frozenTokens[account];
        if (frozenAmt < amount) revert RWAErrors.InsufficientUnfrozenBalance();
        _frozenTokens[account] = frozenAmt - amount;
        emit TokensUnfrozen(account, amount);
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

    /// @dev Gate KYC + pause + freeze en transfers entre wallets. Mint/burn no aplican freeze/pause
    ///      (acciones de agent). Tras burn, se ajusta `frozenTokens` si supera el balance restante.
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) {
            if (_paused) revert RWAErrors.TokenPaused();
            if (_frozen[from] || _frozen[to]) revert RWAErrors.WalletFrozen();
            if (!_identityRegistry.isVerified(from) || !_identityRegistry.isVerified(to)) {
                revert RWAErrors.IdentityNotVerified();
            }
            if (value > getFreeBalance(from)) revert RWAErrors.InsufficientUnfrozenBalance();
        }

        super._update(from, to, value);

        if (from != address(0) && to == address(0)) {
            _syncFrozenTokens(from);
        }
    }

    /// @dev Si tras un burn el balance queda por debajo de `frozenTokens`, recorta el freeze.
    function _syncFrozenTokens(address account) private {
        uint256 bal = balanceOf(account);
        uint256 frozenAmt = _frozenTokens[account];
        if (frozenAmt > bal) {
            _frozenTokens[account] = bal;
        }
    }
}
