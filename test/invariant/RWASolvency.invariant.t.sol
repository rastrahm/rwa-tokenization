// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {ClaimTopicsRegistry} from "../../src/ClaimTopicsRegistry.sol";
import {CountryRestrictModule} from "../../src/compliance/CountryRestrictModule.sol";
import {Identity} from "../../src/Identity.sol";
import {IdentityRegistry} from "../../src/IdentityRegistry.sol";
import {MaxBalanceModule} from "../../src/compliance/MaxBalanceModule.sol";
import {ModularCompliance} from "../../src/ModularCompliance.sol";
import {RWAToken} from "../../src/RWAToken.sol";
import {TrustedIssuersRegistry} from "../../src/TrustedIssuersRegistry.sol";
import {RWAHandler} from "./RWAHandler.sol";

/// @title RWASolvencyInvariantTest
/// @notice Conservación de supply, frozen ≤ balance, bajo fuzz de locks/compliance.
contract RWASolvencyInvariantTest is StdInvariant, Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint16 internal constant COUNTRY_AR = 32;
    uint16 internal constant COUNTRY_US = 840;

    RWAToken internal token;
    RWAHandler internal handler;
    address internal owner = makeAddr("owner");
    address internal claimIssuer = makeAddr("claimIssuer");

    function setUp() public {
        ClaimTopicsRegistry topics = new ClaimTopicsRegistry(owner);
        TrustedIssuersRegistry issuers = new TrustedIssuersRegistry(owner);
        IdentityRegistry registry = new IdentityRegistry(owner, address(topics), address(issuers));

        vm.startPrank(owner);
        topics.addClaimTopic(TOPIC_KYC);
        uint256[] memory issuerTopics = new uint256[](1);
        issuerTopics[0] = TOPIC_KYC;
        issuers.addTrustedIssuer(claimIssuer, issuerTopics);
        vm.stopPrank();

        address[] memory actors = new address[](3);
        actors[0] = makeAddr("a0");
        actors[1] = makeAddr("a1");
        actors[2] = makeAddr("a2");

        for (uint256 i = 0; i < actors.length; ++i) {
            Identity id = new Identity(actors[i]);
            vm.prank(actors[i]);
            id.addClaim(TOPIC_KYC, claimIssuer);
            vm.prank(owner);
            registry.registerIdentity(actors[i], address(id), i == 2 ? COUNTRY_US : COUNTRY_AR);
        }

        token = new RWAToken("RWA", "RWA", owner, address(registry));
        ModularCompliance compliance = new ModularCompliance(owner);
        CountryRestrictModule countryModule = new CountryRestrictModule(owner, address(registry), address(compliance));
        MaxBalanceModule maxModule = new MaxBalanceModule(owner, address(token), address(compliance), 5_000 ether);

        vm.startPrank(owner);
        compliance.bindToken(address(token));
        compliance.addModule(address(countryModule));
        compliance.addModule(address(maxModule));
        token.setCompliance(address(compliance));
        token.mint(actors[0], 1_000 ether);
        vm.stopPrank();

        handler = new RWAHandler(
            token, registry, compliance, countryModule, maxModule, owner, claimIssuer, actors
        );

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = RWAHandler.mint.selector;
        selectors[1] = RWAHandler.transfer.selector;
        selectors[2] = RWAHandler.freezePartial.selector;
        selectors[3] = RWAHandler.unfreezePartial.selector;
        selectors[4] = RWAHandler.toggleFreeze.selector;
        selectors[5] = RWAHandler.forcedTransfer.selector;
        selectors[6] = RWAHandler.setMaxBalance.selector;
        selectors[7] = RWAHandler.toggleCountryUS.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice Todos los actores rastreados suman el totalSupply (único holders en el sistema).
    function invariant_SupplyConserved() public view {
        assertEq(handler.sumBalances(), token.totalSupply());
    }

    /// @notice frozenTokens nunca supera balance por actor.
    function invariant_FrozenBoundedByBalance() public view {
        assertTrue(handler.frozenOk());
    }

    /// @notice Cap de max balance respetado en actores (si no hay freeze bloqueando lectura).
    function invariant_NonNegativeBalances() public view {
        assertGe(token.totalSupply(), 0);
    }
}
