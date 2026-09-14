// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DividendDistributor} from "../src/DividendDistributor.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RWAErrors} from "../src/errors/RWAErrors.sol";
import {RWATestBase} from "./helpers/RWATestBase.sol";

contract DividendDistributorTest is RWATestBase {
    MockERC20 internal usdc;
    DividendDistributor internal dividends;

    uint256 internal constant USDC_TOTAL = 10_000e6;

    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _onboard(charlie, COUNTRY_AR);
        _deployToken();

        usdc = new MockERC20("USD Coin", "USDC", 6);
        dividends = new DividendDistributor(owner, address(token));

        // Holdings: alice 60% / bob 30% / charlie 10%
        vm.startPrank(owner);
        token.mint(alice, 600 ether);
        token.mint(bob, 300 ether);
        token.mint(charlie, 100 ether);
        usdc.mint(owner, USDC_TOTAL);
        vm.stopPrank();
    }

    function _createAndFund() internal returns (uint256 distId, uint256 snapId) {
        vm.prank(owner);
        snapId = token.snapshot();

        vm.startPrank(owner);
        distId = dividends.createDistribution(address(usdc), USDC_TOTAL, snapId);
        usdc.approve(address(dividends), USDC_TOTAL);
        dividends.depositPayment(distId);
        vm.stopPrank();
    }

    function test_ProRataClaims_ThreeInvestors() public {
        (uint256 distId,) = _createAndFund();

        assertEq(dividends.claimable(distId, alice), 6_000e6);
        assertEq(dividends.claimable(distId, bob), 3_000e6);
        assertEq(dividends.claimable(distId, charlie), 1_000e6);

        vm.prank(alice);
        dividends.claim(distId);
        vm.prank(bob);
        dividends.claim(distId);
        vm.prank(charlie);
        dividends.claim(distId);

        assertEq(usdc.balanceOf(alice), 6_000e6);
        assertEq(usdc.balanceOf(bob), 3_000e6);
        assertEq(usdc.balanceOf(charlie), 1_000e6);

        (,,,, uint256 claimedAmount,) = dividends.getDistribution(distId);
        assertEq(claimedAmount, USDC_TOTAL);
        assertEq(usdc.balanceOf(address(dividends)), 0);
    }

    function test_ClaimsUnaffectedByPostSnapshotTransfers() public {
        vm.prank(owner);
        uint256 snapId = token.snapshot();

        vm.prank(alice);
        token.transfer(bob, 600 ether);

        vm.startPrank(owner);
        uint256 distId = dividends.createDistribution(address(usdc), USDC_TOTAL, snapId);
        usdc.approve(address(dividends), USDC_TOTAL);
        dividends.depositPayment(distId);
        vm.stopPrank();

        assertEq(dividends.claimable(distId, alice), 6_000e6);
        assertEq(dividends.claimable(distId, bob), 3_000e6);

        vm.prank(alice);
        dividends.claim(distId);
        assertEq(usdc.balanceOf(alice), 6_000e6);
    }

    function test_DoubleClaim_Reverts() public {
        (uint256 distId,) = _createAndFund();
        vm.prank(alice);
        dividends.claim(distId);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.AlreadyClaimed.selector);
        dividends.claim(distId);
    }

    function test_ClaimBeforeFunding_Reverts() public {
        vm.prank(owner);
        uint256 snapId = token.snapshot();
        vm.prank(owner);
        uint256 distId = dividends.createDistribution(address(usdc), USDC_TOTAL, snapId);

        vm.prank(alice);
        vm.expectRevert(RWAErrors.DistributionNotFunded.selector);
        dividends.claim(distId);
    }

    function test_NothingToClaim_ForNonHolder() public {
        address outsider = makeAddr("outsider");
        _onboard(outsider, COUNTRY_AR);

        (uint256 distId,) = _createAndFund();

        vm.prank(outsider);
        vm.expectRevert(RWAErrors.NothingToClaim.selector);
        dividends.claim(distId);
    }

    function test_InvalidSnapshot_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(RWAErrors.InvalidSnapshot.selector);
        dividends.createDistribution(address(usdc), USDC_TOTAL, 1);
    }

    function test_SumClaimsNeverExceedsTotal_WithDust() public {
        // reward no divisible exacto → floor; suma < reward (dust en contrato)
        uint256 reward = 101;
        usdc.mint(owner, reward);

        vm.prank(owner);
        uint256 snapId = token.snapshot();
        vm.startPrank(owner);
        uint256 distId = dividends.createDistribution(address(usdc), reward, snapId);
        usdc.approve(address(dividends), reward);
        dividends.depositPayment(distId);
        vm.stopPrank();

        uint256 sum = dividends.claimable(distId, alice) + dividends.claimable(distId, bob)
            + dividends.claimable(distId, charlie);
        assertLe(sum, reward);
        assertLt(sum, reward);
    }

    function test_AlreadyFunded_Reverts() public {
        (uint256 distId,) = _createAndFund();
        vm.startPrank(owner);
        usdc.mint(owner, USDC_TOTAL);
        usdc.approve(address(dividends), USDC_TOTAL);
        vm.expectRevert(RWAErrors.AlreadyFunded.selector);
        dividends.depositPayment(distId);
        vm.stopPrank();
    }

    function testFuzz_ClaimSharesNeverExceedTotal(uint256 reward) public {
        reward = bound(reward, 1e6, 1_000_000e6);

        vm.prank(owner);
        uint256 snapId = token.snapshot();

        usdc.mint(owner, reward);
        vm.startPrank(owner);
        uint256 distId = dividends.createDistribution(address(usdc), reward, snapId);
        usdc.approve(address(dividends), reward);
        dividends.depositPayment(distId);
        vm.stopPrank();

        uint256 a = dividends.claimable(distId, alice);
        uint256 b = dividends.claimable(distId, bob);
        uint256 c = dividends.claimable(distId, charlie);
        assertLe(a + b + c, reward);

        if (a > 0) {
            vm.prank(alice);
            dividends.claim(distId);
        }
        if (b > 0) {
            vm.prank(bob);
            dividends.claim(distId);
        }
        if (c > 0) {
            vm.prank(charlie);
            dividends.claim(distId);
        }

        (,,,, uint256 claimedAmount,) = dividends.getDistribution(distId);
        assertLe(claimedAmount, reward);
        assertEq(usdc.balanceOf(address(dividends)), reward - claimedAmount);
    }
}
