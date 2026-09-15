// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CountryRestrictModule} from "../../src/compliance/CountryRestrictModule.sol";
import {MaxBalanceModule} from "../../src/compliance/MaxBalanceModule.sol";
import {ModularCompliance} from "../../src/ModularCompliance.sol";
import {RWAErrors} from "../../src/errors/RWAErrors.sol";
import {RWATestBase} from "../helpers/RWATestBase.sol";

/// @notice Fuzz de freezes parciales y cambios de compliance sin romper supply.
contract TransferLocksFuzzTest is RWATestBase {
    uint16 internal constant COUNTRY_US = 840;

    ModularCompliance internal compliance;
    CountryRestrictModule internal countryModule;
    MaxBalanceModule internal maxBalanceModule;
    address internal usInvestor = makeAddr("usInvestor");

    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _onboard(usInvestor, COUNTRY_US);
        _deployToken();

        compliance = new ModularCompliance(owner);
        countryModule = new CountryRestrictModule(owner, address(registry), address(compliance));
        maxBalanceModule = new MaxBalanceModule(owner, address(token), address(compliance), type(uint256).max);

        vm.startPrank(owner);
        compliance.bindToken(address(token));
        compliance.addModule(address(countryModule));
        compliance.addModule(address(maxBalanceModule));
        token.setCompliance(address(compliance));
        token.mint(alice, 1_000 ether);
        vm.stopPrank();
    }

    function testFuzz_PartialFreeze_TransferPreservesSupply(uint256 freezeAmt, uint256 transferAmt) public {
        freezeAmt = bound(freezeAmt, 0, 1_000 ether);
        if (freezeAmt > 0) {
            vm.prank(owner);
            token.freezePartialTokens(alice, freezeAmt);
        }

        uint256 free = token.getFreeBalance(alice);
        if (free == 0) {
            assertEq(token.totalSupply(), 1_000 ether);
            assertLe(token.getFrozenTokens(alice), token.balanceOf(alice));
            return;
        }

        transferAmt = bound(transferAmt, 1, free);
        vm.prank(alice);
        token.transfer(bob, transferAmt);

        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), 1_000 ether);
        assertLe(token.getFrozenTokens(alice), token.balanceOf(alice));
    }

    function testFuzz_MaxBalanceUpdate_NeverCorruptsSupply(uint256 newMax, uint256 attempt) public {
        newMax = bound(newMax, 1, 2_000 ether);
        vm.prank(owner);
        maxBalanceModule.setMaxBalance(newMax);

        uint256 bobBal = token.balanceOf(bob);
        uint256 room = newMax > bobBal ? newMax - bobBal : 0;
        attempt = bound(attempt, 1, 1_000 ether);

        uint256 aliceBal = token.balanceOf(alice);
        if (aliceBal == 0 || room == 0) {
            assertEq(token.totalSupply(), 1_000 ether);
            return;
        }

        uint256 sendAmt = attempt > aliceBal ? aliceBal : attempt;
        if (sendAmt > room) {
            vm.prank(alice);
            vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
            token.transfer(bob, sendAmt);
        } else {
            vm.prank(alice);
            token.transfer(bob, sendAmt);
        }

        assertEq(token.totalSupply(), 1_000 ether);
        assertLe(token.balanceOf(bob), newMax);
    }

    function testFuzz_CountryRestrictToggle_PreservesAccounting(bool restrictUS, uint256 amount) public {
        amount = bound(amount, 1, token.balanceOf(alice));

        vm.prank(owner);
        countryModule.setCountryRestricted(COUNTRY_US, restrictUS);

        if (restrictUS) {
            vm.prank(alice);
            vm.expectRevert(RWAErrors.TransferNotCompliant.selector);
            token.transfer(usInvestor, amount);
        } else {
            vm.prank(alice);
            token.transfer(usInvestor, amount);
            assertEq(token.balanceOf(usInvestor), amount);
        }

        assertEq(token.totalSupply(), 1_000 ether);
    }

    function testFuzz_ForcedTransfer_FromFrozen_PreservesSupply(uint256 amount) public {
        amount = bound(amount, 1, token.balanceOf(alice));

        vm.prank(owner);
        token.setAddressFrozen(alice, true);

        vm.prank(owner);
        token.forcedTransfer(alice, bob, amount);

        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), 1_000 ether);
    }
}
