// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";
import {RWAErrors} from "./errors/RWAErrors.sol";

/// @title ClaimTopicsRegistry
/// @notice Lista de claim topics obligatorios para pasar `IdentityRegistry.isVerified`.
contract ClaimTopicsRegistry is IClaimTopicsRegistry, Ownable2Step {
    uint256[] private _claimTopics;
    mapping(uint256 topic => bool exists) private _topicExists;

    /// @param initialOwner Owner del registry (issuer / compliance admin).
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc IClaimTopicsRegistry
    function addClaimTopic(uint256 claimTopic) external onlyOwner {
        if (_topicExists[claimTopic]) revert RWAErrors.TopicAlreadyExists();
        _topicExists[claimTopic] = true;
        _claimTopics.push(claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    function removeClaimTopic(uint256 claimTopic) external onlyOwner {
        if (!_topicExists[claimTopic]) revert RWAErrors.TopicDoesNotExist();
        _topicExists[claimTopic] = false;

        uint256 length = _claimTopics.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_claimTopics[i] == claimTopic) {
                _claimTopics[i] = _claimTopics[length - 1];
                _claimTopics.pop();
                break;
            }
        }
    }

    /// @inheritdoc IClaimTopicsRegistry
    function getClaimTopics() external view returns (uint256[] memory topics) {
        return _claimTopics;
    }
}
