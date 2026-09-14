// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RWAErrors} from "../src/errors/RWAErrors.sol";
import {RWATestBase} from "./helpers/RWATestBase.sol";

contract RWATokenTransferTest is RWATestBase {
    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _deployToken();

        vm.prank(owner);
        token.mint(alice, 1_000 ether);
    }

    function test_Mint_ToVerified_OK() public view {
        assertEq(token.balanceOf(alice), 1_000 ether);
        assertEq(token.totalSupply(), 1_000 ether);
    }

    function test_Mint_ToUnverified_RevertsIdentityNotVerified() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.mint(charlie, 100 ether);
    }

    function test_Mint_ZeroAmount_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_Mint_NonAgent_Reverts() public {
        bytes32 agentRole = token.AGENT_ROLE();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, agentRole));
        token.mint(bob, 1 ether);
        vm.stopPrank();
    }

    function test_Transfer_KYCtoKYC_OK() public {
        vm.prank(alice);
        bool ok = token.transfer(bob, 100 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 100 ether);
    }

    function test_Transfer_ToUnverified_RevertsIdentityNotVerified() public {
        vm.prank(alice);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.transfer(charlie, 1 ether);
    }

    function test_Transfer_FromUnverified_RevertsIdentityNotVerified() public {
        // Alice transfiere a bob; luego borramos identidad de alice y bob intenta devolverle
        // (alice deja de estar verified → transfer from alice falla).
        vm.prank(owner);
        registry.deleteIdentity(alice);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.transfer(bob, 1 ether);
    }

    function test_TransferFrom_KYCtoKYC_OK() public {
        vm.prank(alice);
        token.approve(bob, 50 ether);

        vm.prank(bob);
        bool ok = token.transferFrom(alice, bob, 50 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(bob), 50 ether);
        assertEq(token.balanceOf(alice), 950 ether);
    }

    function test_TransferFrom_ToUnverified_Reverts() public {
        vm.prank(alice);
        token.approve(bob, 10 ether);

        vm.prank(bob);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.transferFrom(alice, charlie, 10 ether);
    }

    function test_Burn_ByAgent_OK() public {
        vm.prank(owner);
        token.burn(alice, 200 ether);
        assertEq(token.balanceOf(alice), 800 ether);
        assertEq(token.totalSupply(), 800 ether);
    }

    function test_AddRemoveAgent() public {
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        token.addAgent(agent);
        assertTrue(token.isAgent(agent));

        vm.stopPrank();
        vm.prank(agent);
        token.mint(bob, 5 ether);
        assertEq(token.balanceOf(bob), 5 ether);

        vm.prank(owner);
        token.removeAgent(agent);
        assertFalse(token.isAgent(agent));
    }

    function testFuzz_TransferBetweenVerified(uint256 amount) public {
        amount = bound(amount, 1, token.balanceOf(alice));
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), 1_000 ether);
    }

    function testFuzz_TransferToUnverifiedAlwaysReverts(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(!registry.isVerified(to));
        amount = bound(amount, 1, token.balanceOf(alice));

        vm.prank(alice);
        vm.expectRevert(RWAErrors.IdentityNotVerified.selector);
        token.transfer(to, amount);
    }
}
