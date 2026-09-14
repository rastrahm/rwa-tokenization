// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Custom errors del módulo RWA Tokenization (ERC-3643 / compliance).
library RWAErrors {
    error IdentityNotVerified();
    error TransferNotCompliant();
    error WalletFrozen();
    error InsufficientUnfrozenBalance();
    error TokenPaused();
    error UnauthorizedAgent();
    error ZeroAddress();
    error ZeroAmount();
    error AlreadyClaimed();
    error NothingToClaim();
    error InvalidSnapshot();
    error DistributionNotFunded();
    error InvalidCountry();
    error TopicAlreadyExists();
    error TopicDoesNotExist();
    error IssuerAlreadyExists();
    error IssuerDoesNotExist();
    error IdentityAlreadyRegistered();
    error IdentityNotRegistered();
    error ClaimTopicNotAllowed();
}
