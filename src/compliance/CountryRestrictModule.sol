// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IComplianceModule} from "../interfaces/ICompliance.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {RWAErrors} from "../errors/RWAErrors.sol";

/// @title CountryRestrictModule
/// @notice Bloquea transfers si `from` o `to` tienen un país restringido en el Identity Registry.
contract CountryRestrictModule is IComplianceModule, Ownable2Step {
    IIdentityRegistry public immutable identityRegistry;
    address public immutable override compliance;

    mapping(uint16 country => bool restricted) private _restricted;

    event CountryRestrictionSet(uint16 indexed country, bool restricted);

    /// @param initialOwner Admin del módulo.
    /// @param identityRegistry_ Registry con `investorCountry`.
    /// @param compliance_ ModularCompliance autorizado a llamar hooks.
    constructor(address initialOwner, address identityRegistry_, address compliance_) Ownable(initialOwner) {
        if (identityRegistry_ == address(0) || compliance_ == address(0)) revert RWAErrors.ZeroAddress();
        identityRegistry = IIdentityRegistry(identityRegistry_);
        compliance = compliance_;
    }

    modifier onlyCompliance() {
        if (msg.sender != compliance) revert RWAErrors.OnlyCompliance();
        _;
    }

    /// @notice Marca o desmarca un país como restringido.
    /// @param country Código ISO-3166 numérico.
    /// @param restricted_ True para bloquear.
    function setCountryRestricted(uint16 country, bool restricted_) external onlyOwner {
        _restricted[country] = restricted_;
        emit CountryRestrictionSet(country, restricted_);
    }

    /// @notice True si el país está restringido.
    function isCountryRestricted(uint16 country) external view returns (bool) {
        return _restricted[country];
    }

    /// @inheritdoc IComplianceModule
    function canTransfer(address from, address to, uint256) external view returns (bool) {
        if (from != address(0) && _restricted[identityRegistry.investorCountry(from)]) {
            return false;
        }
        if (to != address(0) && _restricted[identityRegistry.investorCountry(to)]) {
            return false;
        }
        return true;
    }

    /// @inheritdoc IComplianceModule
    function transferred(address, address, uint256) external onlyCompliance {}

    /// @inheritdoc IComplianceModule
    function created(address, uint256) external onlyCompliance {}

    /// @inheritdoc IComplianceModule
    function destroyed(address, uint256) external onlyCompliance {}
}
