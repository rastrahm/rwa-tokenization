// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {IRWAToken} from "./interfaces/IRWAToken.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title RWAToken
/// @notice ERC-20 permissioned: KYC, pause, freeze, forcedTransfer y snapshots para dividendos.
/// @dev Compliance modular se añade en fase COMP.
contract RWAToken is ERC20, AccessControl, IRWAToken {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IIdentityRegistry private _identityRegistry;

    bool private _paused;
    bool private _forcedTransferInProgress;
    mapping(address account => bool frozen) private _frozen;
    mapping(address account => uint256 amount) private _frozenTokens;

    /// @dev Snapshots estilo ERC20Snapshot (OZ v4) — OZ v5 ya no lo incluye.
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    uint256 private _currentSnapshotId;
    mapping(address account => Snapshots) private _accountBalanceSnapshots;
    Snapshots private _totalSupplySnapshots;

    event IdentityRegistrySet(address indexed identityRegistry);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event AddressFrozen(address indexed account, bool indexed isFrozen, address indexed agent);
    event TokensFrozen(address indexed account, uint256 amount);
    event TokensUnfrozen(address indexed account, uint256 amount);
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount, address indexed agent);
    event Snapshot(uint256 indexed snapshotId);

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

    /// @notice Otorga rol de agent (mint/burn/freeze/pause/forcedTransfer).
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

    /// @inheritdoc IRWAToken
    /// @dev Bypassa pause, freeze total/parcial e `isVerified` del `from`. El `to` debe estar verificado
    ///      y no frozen. Ajusta `frozenTokens` del origen si se mueven tokens congelados.
    function forcedTransfer(address from, address to, uint256 amount) external returns (bool success) {
        if (!hasRole(AGENT_ROLE, msg.sender)) revert RWAErrors.UnauthorizedAgent();
        if (from == address(0) || to == address(0)) revert RWAErrors.ZeroAddress();
        if (amount == 0) revert RWAErrors.ZeroAmount();
        if (!_identityRegistry.isVerified(to)) revert RWAErrors.IdentityNotVerified();
        if (_frozen[to]) revert RWAErrors.WalletFrozen();

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) revert RWAErrors.InsufficientBalance();

        uint256 free = getFreeBalance(from);
        if (amount > free) {
            uint256 tokensToUnfreeze = amount - free;
            _frozenTokens[from] -= tokensToUnfreeze;
            emit TokensUnfrozen(from, tokensToUnfreeze);
        }

        _forcedTransferInProgress = true;
        _update(from, to, amount);
        _forcedTransferInProgress = false;

        emit ForcedTransfer(from, to, amount, msg.sender);
        return true;
    }

    /// @inheritdoc IRWAToken
    function snapshot() external onlyRole(AGENT_ROLE) returns (uint256 snapshotId) {
        snapshotId = ++_currentSnapshotId;
        emit Snapshot(snapshotId);
    }

    /// @inheritdoc IRWAToken
    function currentSnapshotId() external view returns (uint256) {
        return _currentSnapshotId;
    }

    /// @inheritdoc IRWAToken
    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _accountBalanceSnapshots[account]);
        return snapshotted ? value : balanceOf(account);
    }

    /// @inheritdoc IRWAToken
    function totalSupplyAt(uint256 snapshotId) public view returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);
        return snapshotted ? value : totalSupply();
    }

    /// @dev Gate KYC + pause + freeze en transfers normales. `forcedTransfer` usa el flag interno.
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0) && !_forcedTransferInProgress) {
            if (_paused) revert RWAErrors.TokenPaused();
            if (_frozen[from] || _frozen[to]) revert RWAErrors.WalletFrozen();
            if (!_identityRegistry.isVerified(from) || !_identityRegistry.isVerified(to)) {
                revert RWAErrors.IdentityNotVerified();
            }
            if (value > getFreeBalance(from)) revert RWAErrors.InsufficientUnfrozenBalance();
        }

        if (from != address(0)) _updateAccountSnapshot(from);
        if (to != address(0)) _updateAccountSnapshot(to);
        if (from == address(0) || to == address(0)) _updateTotalSupplySnapshot();

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

    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(_accountBalanceSnapshots[account], balanceOf(account));
    }

    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(_totalSupplySnapshots, totalSupply());
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = _currentSnapshotId;
        if (currentId == 0) return;
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) return 0;
        return ids[ids.length - 1];
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots)
        private
        view
        returns (bool snapshotted, uint256 value)
    {
        if (snapshotId == 0 || snapshotId > _currentSnapshotId) revert RWAErrors.InvalidSnapshot();

        uint256 length = snapshots.ids.length;
        if (length == 0) return (false, 0);

        // Binary search: mayor id <= snapshotId.
        uint256 low = 0;
        uint256 high = length;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (snapshots.ids[mid] > snapshotId) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (low == 0) return (false, 0);
        return (true, snapshots.values[low - 1]);
    }
}
