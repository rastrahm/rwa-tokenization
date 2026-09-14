// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title TrustedIssuersRegistry
/// @notice Emisores de claims KYC/AML autorizados y topics que pueden emitir.
contract TrustedIssuersRegistry is ITrustedIssuersRegistry, Ownable2Step {
    address[] private _issuers;
    mapping(address issuer => bool trusted) private _isTrusted;
    mapping(address issuer => uint256[] topics) private _issuerTopics;
    mapping(address issuer => mapping(uint256 topic => bool allowed)) private _hasTopic;

    /// @param initialOwner Owner del registry.
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc ITrustedIssuersRegistry
    function addTrustedIssuer(address trustedIssuer, uint256[] calldata claimTopics) external onlyOwner {
        if (trustedIssuer == address(0)) revert RWAErrors.ZeroAddress();
        if (_isTrusted[trustedIssuer]) revert RWAErrors.IssuerAlreadyExists();

        _isTrusted[trustedIssuer] = true;
        _issuers.push(trustedIssuer);
        _setIssuerTopics(trustedIssuer, claimTopics);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function removeTrustedIssuer(address trustedIssuer) external onlyOwner {
        if (!_isTrusted[trustedIssuer]) revert RWAErrors.IssuerDoesNotExist();

        _clearIssuerTopics(trustedIssuer);
        _isTrusted[trustedIssuer] = false;

        uint256 length = _issuers.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_issuers[i] == trustedIssuer) {
                _issuers[i] = _issuers[length - 1];
                _issuers.pop();
                break;
            }
        }
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function updateIssuerClaimTopics(address trustedIssuer, uint256[] calldata claimTopics) external onlyOwner {
        if (!_isTrusted[trustedIssuer]) revert RWAErrors.IssuerDoesNotExist();
        _clearIssuerTopics(trustedIssuer);
        _setIssuerTopics(trustedIssuer, claimTopics);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function isTrustedIssuer(address issuer) external view returns (bool trusted) {
        return _isTrusted[issuer];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function hasClaimTopic(address issuer, uint256 claimTopic) external view returns (bool allowed) {
        return _hasTopic[issuer][claimTopic];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuers() external view returns (address[] memory issuers) {
        return _issuers;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(address trustedIssuer)
        external
        view
        returns (uint256[] memory claimTopics)
    {
        if (!_isTrusted[trustedIssuer]) revert RWAErrors.IssuerDoesNotExist();
        return _issuerTopics[trustedIssuer];
    }

    function _setIssuerTopics(address issuer, uint256[] calldata claimTopics) private {
        uint256 length = claimTopics.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 topic = claimTopics[i];
            if (!_hasTopic[issuer][topic]) {
                _hasTopic[issuer][topic] = true;
                _issuerTopics[issuer].push(topic);
            }
        }
    }

    function _clearIssuerTopics(address issuer) private {
        uint256[] storage topics = _issuerTopics[issuer];
        uint256 length = topics.length;
        for (uint256 i = 0; i < length; ++i) {
            _hasTopic[issuer][topics[i]] = false;
        }
        delete _issuerTopics[issuer];
    }
}
