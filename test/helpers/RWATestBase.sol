// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ClaimTopicsRegistry} from "../../src/ClaimTopicsRegistry.sol";
import {Identity} from "../../src/Identity.sol";
import {IdentityRegistry} from "../../src/IdentityRegistry.sol";
import {RWAToken} from "../../src/RWAToken.sol";
import {TrustedIssuersRegistry} from "../../src/TrustedIssuersRegistry.sol";

/// @dev Helper compartido: despliega identity stack + onboarding KYC.
abstract contract RWATestBase is Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint16 internal constant COUNTRY_AR = 32;

    address internal owner = makeAddr("owner");
    address internal claimIssuer = makeAddr("claimIssuer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie"); // sin KYC

    ClaimTopicsRegistry internal topics;
    TrustedIssuersRegistry internal issuers;
    IdentityRegistry internal registry;
    RWAToken internal token;

    function _deployIdentityStack() internal {
        vm.startPrank(owner);
        topics = new ClaimTopicsRegistry(owner);
        issuers = new TrustedIssuersRegistry(owner);
        registry = new IdentityRegistry(owner, address(topics), address(issuers));
        topics.addClaimTopic(TOPIC_KYC);

        uint256[] memory issuerTopics = new uint256[](1);
        issuerTopics[0] = TOPIC_KYC;
        issuers.addTrustedIssuer(claimIssuer, issuerTopics);
        vm.stopPrank();
    }

    function _onboard(address user, uint16 country) internal returns (Identity id) {
        id = new Identity(user);
        vm.prank(user);
        id.addClaim(TOPIC_KYC, claimIssuer);
        vm.prank(owner);
        registry.registerIdentity(user, address(id), country);
    }

    function _deployToken() internal {
        vm.prank(owner);
        token = new RWAToken("RWA Real Estate", "rRE", owner, address(registry));
    }
}
