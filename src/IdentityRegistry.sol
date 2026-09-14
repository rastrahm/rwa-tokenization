// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";
import {IIdentity} from "./interfaces/IIdentity.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title IdentityRegistry
/// @notice Vincula wallets a identidades ONCHAINID y expone `isVerified` para transfers permissioned.
contract IdentityRegistry is IIdentityRegistry, Ownable2Step {
    IClaimTopicsRegistry private immutable CLAIM_TOPICS_REGISTRY;
    ITrustedIssuersRegistry private immutable TRUSTED_ISSUERS_REGISTRY;

    mapping(address user => address identityContract) private _identities;
    mapping(address user => uint16 country) private _countries;

    event IdentityRegistered(address indexed userAddress, address indexed identityAddress, uint16 country);
    event IdentityRemoved(address indexed userAddress, address indexed identityAddress);
    event IdentityUpdated(address indexed userAddress, address indexed oldIdentity, address indexed newIdentity);
    event CountryUpdated(address indexed userAddress, uint16 indexed country);

    /// @param initialOwner Agent/issuer que registra identidades.
    /// @param claimTopicsRegistry_ Registry de topics obligatorios.
    /// @param trustedIssuersRegistry_ Registry de emisores confiables.
    constructor(address initialOwner, address claimTopicsRegistry_, address trustedIssuersRegistry_)
        Ownable(initialOwner)
    {
        if (claimTopicsRegistry_ == address(0) || trustedIssuersRegistry_ == address(0)) {
            revert RWAErrors.ZeroAddress();
        }
        CLAIM_TOPICS_REGISTRY = IClaimTopicsRegistry(claimTopicsRegistry_);
        TRUSTED_ISSUERS_REGISTRY = ITrustedIssuersRegistry(trustedIssuersRegistry_);
    }

    /// @inheritdoc IIdentityRegistry
    function claimTopicsRegistry() external view returns (address) {
        return address(CLAIM_TOPICS_REGISTRY);
    }

    /// @inheritdoc IIdentityRegistry
    function trustedIssuersRegistry() external view returns (address) {
        return address(TRUSTED_ISSUERS_REGISTRY);
    }

    /// @inheritdoc IIdentityRegistry
    function registerIdentity(address userAddress, address identityAddress, uint16 country) external onlyOwner {
        if (userAddress == address(0) || identityAddress == address(0)) revert RWAErrors.ZeroAddress();
        if (_identities[userAddress] != address(0)) revert RWAErrors.IdentityAlreadyRegistered();

        _identities[userAddress] = identityAddress;
        _countries[userAddress] = country;
        emit IdentityRegistered(userAddress, identityAddress, country);
    }

    /// @inheritdoc IIdentityRegistry
    function deleteIdentity(address userAddress) external onlyOwner {
        address identityAddress = _identities[userAddress];
        if (identityAddress == address(0)) revert RWAErrors.IdentityNotRegistered();

        delete _identities[userAddress];
        delete _countries[userAddress];
        emit IdentityRemoved(userAddress, identityAddress);
    }

    /// @inheritdoc IIdentityRegistry
    function updateIdentity(address userAddress, address identityAddress) external onlyOwner {
        if (identityAddress == address(0)) revert RWAErrors.ZeroAddress();
        address oldIdentity = _identities[userAddress];
        if (oldIdentity == address(0)) revert RWAErrors.IdentityNotRegistered();

        _identities[userAddress] = identityAddress;
        emit IdentityUpdated(userAddress, oldIdentity, identityAddress);
    }

    /// @inheritdoc IIdentityRegistry
    function updateCountry(address userAddress, uint16 country) external onlyOwner {
        if (_identities[userAddress] == address(0)) revert RWAErrors.IdentityNotRegistered();
        _countries[userAddress] = country;
        emit CountryUpdated(userAddress, country);
    }

    /// @inheritdoc IIdentityRegistry
    function isVerified(address userAddress) public view returns (bool verified) {
        address identityAddress = _identities[userAddress];
        if (identityAddress == address(0)) return false;

        uint256[] memory topics = CLAIM_TOPICS_REGISTRY.getClaimTopics();
        uint256 length = topics.length;
        // Sin topics obligatorios: basta con estar registrado.
        if (length == 0) return true;

        IIdentity id = IIdentity(identityAddress);
        for (uint256 i = 0; i < length; ++i) {
            uint256 topic = topics[i];
            (address issuer, bool valid) = id.getClaim(topic);
            if (!valid || issuer == address(0)) return false;
            if (!TRUSTED_ISSUERS_REGISTRY.isTrustedIssuer(issuer)) return false;
            if (!TRUSTED_ISSUERS_REGISTRY.hasClaimTopic(issuer, topic)) return false;
        }
        return true;
    }

    /// @inheritdoc IIdentityRegistry
    function identity(address userAddress) external view returns (address identityAddress) {
        return _identities[userAddress];
    }

    /// @inheritdoc IIdentityRegistry
    function investorCountry(address userAddress) external view returns (uint16 country) {
        return _countries[userAddress];
    }

    /// @inheritdoc IIdentityRegistry
    function contains(address userAddress) external view returns (bool registered) {
        return _identities[userAddress] != address(0);
    }
}
