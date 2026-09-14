// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CountryRestrictModule} from "../src/compliance/CountryRestrictModule.sol";
import {MaxBalanceModule} from "../src/compliance/MaxBalanceModule.sol";
import {ModularCompliance} from "../src/ModularCompliance.sol";
import {RWAErrors} from "../src/errors/RWAErrors.sol";
import {RWATestBase} from "./helpers/RWATestBase.sol";

contract ModularComplianceTest is RWATestBase {
    uint16 internal constant COUNTRY_US = 840;
    uint16 internal constant COUNTRY_IR = 364; // Iran — restringido en tests

    ModularCompliance internal compliance;
    CountryRestrictModule internal countryModule;
    MaxBalanceModule internal maxBalanceModule;

    address internal usInvestor = makeAddr("usInvestor");
    address internal irInvestor = makeAddr("irInvestor");

    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _onboard(usInvestor, COUNTRY_US);
        _onboard(irInvestor, COUNTRY_IR);
        _deployToken();

        compliance = new ModularCompliance(owner);
        countryModule = new CountryRestrictModule(owner, address(registry), address(compliance));
        maxBalanceModule = new MaxBalanceModule(owner, address(token), address(compliance), 500 ether);

        vm.startPrank(owner);
        compliance.bindToken(address(token));
        compliance.addModule(address(countryModule));
        compliance.addModule(address(maxBalanceModule));
        token.setCompliance(address(compliance));
        countryModule.setCountryRestricted(COUNTRY_IR, true);

        token.mint(alice, 400 ether);
        token.mint(bob, 100 ether);
        vm.stopPrank();
    }

    function test_Transfer_OK_WhenCompliant() public {
        vm.prank(alice);
        token.transfer(bob, 50 ether);
        assertEq(token.balanceOf(bob), 150 ether);
    }

    function test_CountryRestrict_BlocksTransferToRestricted() public {
        vm.prank(alice);
        vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
        token.transfer(irInvestor, 1 ether);
    }

    function test_CountryRestrict_BlocksTransferFromRestricted() public {
        // Mint to IR via agent would also fail max/country on mint — force path:
        // Temporarily lift country, mint, re-restrict, then transfer from IR
        vm.startPrank(owner);
        countryModule.setCountryRestricted(COUNTRY_IR, false);
        token.mint(irInvestor, 10 ether);
        countryModule.setCountryRestricted(COUNTRY_IR, true);
        vm.stopPrank();

        vm.prank(irInvestor);
        vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
        token.transfer(alice, 1 ether);
    }

    function test_MaxBalance_BlocksTransferExceedingCap() public {
        // bob has 100; max 500 → can receive 400 more, not 401
        vm.prank(alice);
        token.transfer(bob, 400 ether);
        assertEq(token.balanceOf(bob), 500 ether);

        vm.prank(owner);
        token.mint(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
        token.transfer(bob, 1 ether);
    }

    function test_MaxBalance_BlocksMintExceedingCap() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
        token.mint(alice, 101 ether); // alice already 400 → 501 > 500
    }

    function test_KYCStillRequired_WithCompliance() public {
        vm.prank(alice);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.transfer(charlie, 1 ether);
    }

    function test_RemoveCountryModule_AllowsRestrictedCountry() public {
        vm.prank(owner);
        compliance.removeModule(address(countryModule));

        // max balance still applies; mint 50 to IR (IR has 0)
        vm.prank(owner);
        token.mint(irInvestor, 50 ether);
        assertEq(token.balanceOf(irInvestor), 50 ether);
    }

    function test_ForcedTransfer_BypassesCanTransfer() public {
        // Alice frozen + IR restricted destination blocked normally; forced to usInvestor OK
        vm.startPrank(owner);
        token.setAddressFrozen(alice, true);
        bool ok = token.forcedTransfer(alice, usInvestor, 100 ether);
        vm.stopPrank();

        assertTrue(ok);
        assertEq(token.balanceOf(usInvestor), 100 ether);
    }

    function test_BindToken_OnlyOnce() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.TokenAlreadyBound.selector);
        compliance.bindToken(address(token));
    }
}
