// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICompliance, IComplianceModule} from "./interfaces/ICompliance.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title ModularCompliance
/// @notice Agrega módulos `canTransfer` / hooks post-movimiento para el RWA token.
contract ModularCompliance is ICompliance, Ownable2Step {
    address private _tokenBound;
    address[] private _modules;
    mapping(address module => bool added) private _moduleAdded;

    event TokenBound(address indexed token);
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);

    /// @param initialOwner Compliance admin.
    constructor(address initialOwner) Ownable(initialOwner) {}

    modifier onlyBoundToken() {
        if (msg.sender != _tokenBound) revert RWAErrors.OnlyBoundToken();
        _;
    }

    /// @inheritdoc ICompliance
    function tokenBound() external view returns (address) {
        return _tokenBound;
    }

    /// @notice Lista de módulos activos.
    function getModules() external view returns (address[] memory) {
        return _modules;
    }

    /// @inheritdoc ICompliance
    function bindToken(address token) external onlyOwner {
        if (token == address(0)) revert RWAErrors.ZeroAddress();
        if (_tokenBound != address(0)) revert RWAErrors.TokenAlreadyBound();
        _tokenBound = token;
        emit TokenBound(token);
    }

    /// @notice Añade un módulo de compliance.
    /// @param module Dirección del módulo.
    function addModule(address module) external onlyOwner {
        if (module == address(0)) revert RWAErrors.ZeroAddress();
        if (_moduleAdded[module]) revert RWAErrors.ModuleAlreadyAdded();
        _moduleAdded[module] = true;
        _modules.push(module);
        emit ModuleAdded(module);
    }

    /// @notice Elimina un módulo de compliance.
    /// @param module Dirección del módulo.
    function removeModule(address module) external onlyOwner {
        if (!_moduleAdded[module]) revert RWAErrors.ModuleNotFound();
        _moduleAdded[module] = false;

        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_modules[i] == module) {
                _modules[i] = _modules[length - 1];
                _modules.pop();
                break;
            }
        }
        emit ModuleRemoved(module);
    }

    /// @inheritdoc ICompliance
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ++i) {
            if (!IComplianceModule(_modules[i]).canTransfer(from, to, amount)) {
                return false;
            }
        }
        return true;
    }

    /// @inheritdoc ICompliance
    function transferred(address from, address to, uint256 amount) external onlyBoundToken {
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ++i) {
            IComplianceModule(_modules[i]).transferred(from, to, amount);
        }
    }

    /// @inheritdoc ICompliance
    function created(address to, uint256 amount) external onlyBoundToken {
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ++i) {
            IComplianceModule(_modules[i]).created(to, amount);
        }
    }

    /// @inheritdoc ICompliance
    function destroyed(address from, uint256 amount) external onlyBoundToken {
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ++i) {
            IComplianceModule(_modules[i]).destroyed(from, amount);
        }
    }
}
