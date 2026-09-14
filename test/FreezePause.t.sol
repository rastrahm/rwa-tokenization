// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RWAErrors} from "../src/errors/RWAErrors.sol";
import {RWATestBase} from "./helpers/RWATestBase.sol";

contract FreezePauseTest is RWATestBase {
    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _deployToken();

        vm.prank(owner);
        token.mint(alice, 1_000 ether);
    }

    function test_Pause_BlocksTransfer() public {
        vm.prank(owner);
        token.pause();
        assertTrue(token.paused());

        vm.prank(alice);
        vm.expectRevert(RWAErrors.TokenPaused.selector);
        token.transfer(bob, 1 ether);

        // totalSupply intacto
        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function test_Unpause_AllowsTransfer() public {
        vm.startPrank(owner);
        token.pause();
        token.unpause();
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 10 ether);
        assertEq(token.balanceOf(bob), 10 ether);
        assertEq(token.totalSupply(), 1_000 ether);
    }

    function test_Pause_NonAgent_Reverts() public {
        bytes32 agentRole = token.AGENT_ROLE();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, agentRole));
        token.pause();
        vm.stopPrank();
    }

    function test_FreezeTotal_BlocksTransferFromAndTo() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(owner);
        token.setAddressFrozen(alice, true);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.WalletFrozen.selector);
        token.transfer(bob, 1 ether);

        vm.prank(owner);
        token.setAddressFrozen(alice, false);
        vm.prank(owner);
        token.setAddressFrozen(bob, true);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.WalletFrozen.selector);
        token.transfer(bob, 1 ether);

        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function test_FreezePartial_AllowsOnlyFreeBalance() public {
        vm.prank(owner);
        token.freezePartialTokens(alice, 700 ether);

        assertEq(token.getFrozenTokens(alice), 700 ether);
        assertEq(token.getFreeBalance(alice), 300 ether);
        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice), 1_000 ether);

        vm.prank(alice);
        token.transfer(bob, 300 ether);
        assertEq(token.balanceOf(bob), 300 ether);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.InsufficientUnfrozenBalance.selector);
        token.transfer(bob, 1);
    }

    function test_FreezePartial_ExceedsFree_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.InsufficientUnfrozenBalance.selector);
        token.freezePartialTokens(alice, 1_001 ether);
    }

    function test_UnfreezePartial_RestoresSpendable() public {
        vm.startPrank(owner);
        token.freezePartialTokens(alice, 800 ether);
        token.unfreezePartialTokens(alice, 500 ether);
        vm.stopPrank();

        assertEq(token.getFrozenTokens(alice), 300 ether);
        assertEq(token.getFreeBalance(alice), 700 ether);

        vm.prank(alice);
        token.transfer(bob, 700 ether);
        assertEq(token.totalSupply(), 1_000 ether);
    }

    function test_Burn_SyncsFrozenTokens_SupplyConsistent() public {
        vm.prank(owner);
        token.freezePartialTokens(alice, 600 ether);

        vm.prank(owner);
        token.burn(alice, 500 ether);

        // balance 500, frozen was 600 → sync a 500
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.getFrozenTokens(alice), 500 ether);
        assertEq(token.totalSupply(), 500 ether);
        assertEq(token.getFreeBalance(alice), 0);
    }

    function test_MintWhilePaused_StillAllowed() public {
        // Pause solo bloquea transfers wallet↔wallet; mint de agent sigue OK.
        vm.startPrank(owner);
        token.pause();
        token.mint(bob, 50 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 50 ether);
        assertEq(token.totalSupply(), 1_050 ether);
    }

    function testFuzz_PartialFreeze_NeverCorruptsSupply(uint256 freezeAmt, uint256 transferAmt) public {
        freezeAmt = bound(freezeAmt, 0, 1_000 ether);
        if (freezeAmt > 0) {
            vm.prank(owner);
            token.freezePartialTokens(alice, freezeAmt);
        }

        uint256 free = token.getFreeBalance(alice);
        if (free == 0) {
            assertEq(token.totalSupply(), 1_000 ether);
            return;
        }

        transferAmt = bound(transferAmt, 1, free);
        vm.prank(alice);
        token.transfer(bob, transferAmt);

        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), 1_000 ether);
        assertEq(token.getFrozenTokens(alice) + token.getFreeBalance(alice), token.balanceOf(alice));
    }
}
