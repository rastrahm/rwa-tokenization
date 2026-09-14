// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RWAErrors} from "../src/errors/RWAErrors.sol";
import {RWATestBase} from "./helpers/RWATestBase.sol";

contract ForcedTransferTest is RWATestBase {
    address internal newWallet = makeAddr("newWallet");

    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _onboard(newWallet, COUNTRY_AR);
        _deployToken();

        vm.prank(owner);
        token.mint(alice, 1_000 ether);
    }

    function test_ForcedTransfer_FromFrozenWallet_ToVerified() public {
        vm.prank(owner);
        token.setAddressFrozen(alice, true);

        // Alice no puede transferir normalmente
        vm.prank(alice);
        vm.expectRevert(RWAErrors.WalletFrozen.selector);
        token.transfer(bob, 100 ether);

        // Agent recupera hacia nueva identidad verificada
        vm.prank(owner);
        bool ok = token.forcedTransfer(alice, newWallet, 400 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 600 ether);
        assertEq(token.balanceOf(newWallet), 400 ether);
        assertEq(token.totalSupply(), 1_000 ether);
        assertTrue(token.isFrozen(alice)); // freeze del origen se mantiene
    }

    function test_ForcedTransfer_WhilePaused() public {
        vm.startPrank(owner);
        token.pause();
        bool ok = token.forcedTransfer(alice, newWallet, 250 ether);
        vm.stopPrank();

        assertTrue(ok);
        assertEq(token.balanceOf(newWallet), 250 ether);
        assertTrue(token.paused());
    }

    function test_ForcedTransfer_MovesPartialFrozenTokens() public {
        vm.prank(owner);
        token.freezePartialTokens(alice, 800 ether);

        assertEq(token.getFreeBalance(alice), 200 ether);

        vm.prank(owner);
        token.forcedTransfer(alice, newWallet, 500 ether);

        // Se liberaron 300 frozen para completar los 500
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.getFrozenTokens(alice), 500 ether);
        assertEq(token.getFreeBalance(alice), 0);
        assertEq(token.balanceOf(newWallet), 500 ether);
        assertEq(token.totalSupply(), 1_000 ether);
    }

    function test_ForcedTransfer_FromUnverifiedSender_OK() public {
        // Wallet perdida: se borra KYC del origen; agent igual puede recuperar
        vm.prank(owner);
        registry.deleteIdentity(alice);
        assertFalse(registry.isVerified(alice));

        vm.prank(owner);
        token.forcedTransfer(alice, newWallet, 100 ether);

        assertEq(token.balanceOf(newWallet), 100 ether);
    }

    function test_ForcedTransfer_ToUnverified_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.forcedTransfer(alice, charlie, 10 ether);
    }

    function test_ForcedTransfer_ToFrozen_Reverts() public {
        vm.prank(owner);
        token.setAddressFrozen(newWallet, true);

        vm.prank(owner);
        vm.expectRevert(RWAErrors.WalletFrozen.selector);
        token.forcedTransfer(alice, newWallet, 10 ether);
    }

    function test_ForcedTransfer_NonAgent_RevertsUnauthorizedAgent() public {
        vm.prank(alice);
        vm.expectRevert(RWAErrors.UnauthorizedAgent.selector);
        token.forcedTransfer(alice, newWallet, 10 ether);
    }

    function test_ForcedTransfer_InsufficientBalance_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.InsufficientBalance.selector);
        token.forcedTransfer(alice, newWallet, 1_001 ether);
    }

    function test_ForcedTransfer_ZeroAmount_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.ZeroAmount.selector);
        token.forcedTransfer(alice, newWallet, 0);
    }

    function test_ForcedTransfer_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ForcedTransfer(alice, newWallet, 77 ether, owner);
        token.forcedTransfer(alice, newWallet, 77 ether);
    }

    function testFuzz_ForcedTransfer_PreservesSupply(uint256 amount) public {
        amount = bound(amount, 1, 1_000 ether);

        vm.prank(owner);
        token.setAddressFrozen(alice, true);

        vm.prank(owner);
        token.forcedTransfer(alice, newWallet, amount);

        assertEq(token.totalSupply(), 1_000 ether);
        assertEq(token.balanceOf(alice) + token.balanceOf(newWallet) + token.balanceOf(bob), 1_000 ether);
    }

    /// @dev Mirror del evento del contrato para `vm.expectEmit`.
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount, address indexed agent);
}
