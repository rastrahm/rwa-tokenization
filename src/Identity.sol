// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IIdentity} from "./interfaces/IIdentity.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title Identity
/// @notice Identidad lab estilo ONCHAINID: almacena claims (topic → issuer) gestionados por el owner.
contract Identity is IIdentity, Ownable2Step {
    struct Claim {
        address issuer;
        bool valid;
    }

    mapping(uint256 topic => Claim claim) private _claims;

    /// @param initialOwner Management key de la identidad (inversor o custodio de lab).
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert RWAErrors.ZeroAddress();
    }

    /// @inheritdoc IIdentity
    function addClaim(uint256 topic, address issuer) external onlyOwner {
        if (issuer == address(0)) revert RWAErrors.ZeroAddress();
        _claims[topic] = Claim({issuer: issuer, valid: true});
    }

    /// @inheritdoc IIdentity
    function removeClaim(uint256 topic) external onlyOwner {
        delete _claims[topic];
    }

    /// @inheritdoc IIdentity
    function getClaim(uint256 topic) external view returns (address issuer, bool valid) {
        Claim memory claim = _claims[topic];
        return (claim.issuer, claim.valid);
    }
}
