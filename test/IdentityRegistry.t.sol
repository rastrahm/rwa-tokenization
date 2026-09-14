// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {Identity} from "../src/Identity.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {RWAErrors} from "../src/errors/RWAErrors.sol";

contract IdentityRegistryTest is Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_AML = 2;
    uint16 internal constant COUNTRY_AR = 32;

    address internal owner = makeAddr("owner");
    address internal claimIssuer = makeAddr("claimIssuer");
    address internal untrustedIssuer = makeAddr("untrustedIssuer");
    address internal investor = makeAddr("investor");
    address internal other = makeAddr("other");

    ClaimTopicsRegistry internal topics;
    TrustedIssuersRegistry internal issuers;
    IdentityRegistry internal registry;
    Identity internal investorIdentity;

    function setUp() public {
        vm.startPrank(owner);
        topics = new ClaimTopicsRegistry(owner);
        issuers = new TrustedIssuersRegistry(owner);
        registry = new IdentityRegistry(owner, address(topics), address(issuers));

        topics.addClaimTopic(TOPIC_KYC);

        uint256[] memory issuerTopics = new uint256[](1);
        issuerTopics[0] = TOPIC_KYC;
        issuers.addTrustedIssuer(claimIssuer, issuerTopics);
        vm.stopPrank();

        investorIdentity = new Identity(investor);
        vm.prank(investor);
        investorIdentity.addClaim(TOPIC_KYC, claimIssuer);
    }

    function test_UnregisteredIsNotVerified() public view {
        assertFalse(registry.isVerified(investor));
        assertFalse(registry.contains(investor));
    }

    function test_RegisteredWithoutRequiredClaimIsNotVerified() public {
        Identity bare = new Identity(investor);
        vm.prank(owner);
        registry.registerIdentity(investor, address(bare), COUNTRY_AR);

        assertTrue(registry.contains(investor));
        assertFalse(registry.isVerified(investor));
    }

    function test_RegisteredWithTrustedClaimIsVerified() public {
        vm.prank(owner);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);

        assertTrue(registry.isVerified(investor));
        assertEq(registry.identity(investor), address(investorIdentity));
        assertEq(registry.investorCountry(investor), COUNTRY_AR);
    }

    function test_IncompleteTopicsIsNotVerified() public {
        vm.startPrank(owner);
        topics.addClaimTopic(TOPIC_AML);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        vm.stopPrank();

        // Solo tiene KYC; falta AML.
        assertFalse(registry.isVerified(investor));

        // Emisor confiable también para AML + claim en identity → verified.
        uint256[] memory both = new uint256[](2);
        both[0] = TOPIC_KYC;
        both[1] = TOPIC_AML;
        vm.prank(owner);
        issuers.updateIssuerClaimTopics(claimIssuer, both);

        vm.prank(investor);
        investorIdentity.addClaim(TOPIC_AML, claimIssuer);

        assertTrue(registry.isVerified(investor));
    }

    function test_ClaimFromUntrustedIssuerIsNotVerified() public {
        Identity id = new Identity(investor);
        vm.prank(investor);
        id.addClaim(TOPIC_KYC, untrustedIssuer);

        vm.prank(owner);
        registry.registerIdentity(investor, address(id), COUNTRY_AR);

        assertFalse(registry.isVerified(investor));
    }

    function test_TrustedIssuerWithoutTopicPermissionIsNotVerified() public {
        // claimIssuer solo autorizado para KYC; añadimos AML como topic requerido y claim AML del mismo issuer.
        vm.startPrank(owner);
        topics.addClaimTopic(TOPIC_AML);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        vm.stopPrank();

        vm.prank(investor);
        investorIdentity.addClaim(TOPIC_AML, claimIssuer);

        assertFalse(registry.isVerified(investor));
    }

    function test_DeleteIdentityRemovesVerification() public {
        vm.prank(owner);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        assertTrue(registry.isVerified(investor));

        vm.prank(owner);
        registry.deleteIdentity(investor);

        assertFalse(registry.contains(investor));
        assertFalse(registry.isVerified(investor));
        assertEq(registry.identity(investor), address(0));
    }

    function test_UpdateIdentityAndCountry() public {
        vm.prank(owner);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);

        Identity newId = new Identity(investor);
        vm.prank(investor);
        newId.addClaim(TOPIC_KYC, claimIssuer);

        vm.startPrank(owner);
        registry.updateIdentity(investor, address(newId));
        registry.updateCountry(investor, 840);
        vm.stopPrank();

        assertEq(registry.identity(investor), address(newId));
        assertEq(registry.investorCountry(investor), 840);
        assertTrue(registry.isVerified(investor));
    }

    function test_RegisterIdentity_RevertsZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(RWAErrors.ZeroAddress.selector);
        registry.registerIdentity(address(0), address(investorIdentity), COUNTRY_AR);

        vm.expectRevert(RWAErrors.ZeroAddress.selector);
        registry.registerIdentity(investor, address(0), COUNTRY_AR);
        vm.stopPrank();
    }

    function test_RegisterIdentity_RevertsAlreadyRegistered() public {
        vm.startPrank(owner);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        vm.expectRevert(RWAErrors.IdentityAlreadyRegistered.selector);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        vm.stopPrank();
    }

    function test_DeleteIdentity_RevertsNotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.IdentityNotRegistered.selector);
        registry.deleteIdentity(investor);
    }

    function test_OnlyOwnerCanRegister() public {
        vm.prank(other);
        vm.expectRevert();
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
    }

    function test_NoRequiredTopics_RegisteredIsVerified() public {
        vm.startPrank(owner);
        topics.removeClaimTopic(TOPIC_KYC);
        registry.registerIdentity(investor, address(investorIdentity), COUNTRY_AR);
        vm.stopPrank();

        assertTrue(registry.isVerified(investor));
    }

    function test_ClaimTopicsRegistry_AddRemove() public {
        vm.startPrank(owner);
        topics.addClaimTopic(TOPIC_AML);
        uint256[] memory list = topics.getClaimTopics();
        assertEq(list.length, 2);

        vm.expectRevert(RWAErrors.TopicAlreadyExists.selector);
        topics.addClaimTopic(TOPIC_AML);

        topics.removeClaimTopic(TOPIC_AML);
        list = topics.getClaimTopics();
        assertEq(list.length, 1);
        assertEq(list[0], TOPIC_KYC);
        vm.stopPrank();
    }

    function test_TrustedIssuersRegistry_AddRemove() public {
        address another = makeAddr("anotherIssuer");
        uint256[] memory t = new uint256[](1);
        t[0] = TOPIC_KYC;

        vm.startPrank(owner);
        issuers.addTrustedIssuer(another, t);
        assertTrue(issuers.isTrustedIssuer(another));
        assertTrue(issuers.hasClaimTopic(another, TOPIC_KYC));

        issuers.removeTrustedIssuer(another);
        assertFalse(issuers.isTrustedIssuer(another));
        vm.stopPrank();
    }

    function testFuzz_RandomAddressNotVerifiedUnlessOnboarded(address user) public view {
        vm.assume(user != investor);
        assertFalse(registry.isVerified(user));
    }

    function testFuzz_VerifiedAfterFullOnboarding(address user, uint16 country) public {
        vm.assume(user != address(0));
        vm.assume(user != owner);

        Identity id = new Identity(user);
        vm.prank(user);
        id.addClaim(TOPIC_KYC, claimIssuer);

        vm.prank(owner);
        registry.registerIdentity(user, address(id), country);

        assertTrue(registry.isVerified(user));
        assertEq(registry.investorCountry(user), country);
    }
}
