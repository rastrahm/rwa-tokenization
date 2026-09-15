// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DividendDistributor} from "../../src/DividendDistributor.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {RWATestBase} from "../helpers/RWATestBase.sol";

/**
 * @title RWATokenGasTest
 * @notice Baseline gas hot paths (`forge snapshot --match-contract RWATokenGasTest`).
 */
contract RWATokenGasTest is RWATestBase {
    DividendDistributor internal dividends;
    MockERC20 internal usdc;

    function setUp() public {
        _deployIdentityStack();
        _onboard(alice, COUNTRY_AR);
        _onboard(bob, COUNTRY_AR);
        _deployToken();

        dividends = new DividendDistributor(owner, address(token));
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(owner);
        token.mint(alice, 1_000 ether);
        usdc.mint(owner, 10_000e6);
        vm.stopPrank();
    }

    function testGas_transfer() public {
        vm.prank(alice);
        token.transfer(bob, 100 ether);
    }

    function testGas_freezePartial() public {
        vm.prank(owner);
        token.freezePartialTokens(alice, 200 ether);
    }

    function testGas_forcedTransfer() public {
        vm.prank(owner);
        token.setAddressFrozen(alice, true);
        vm.prank(owner);
        token.forcedTransfer(alice, bob, 50 ether);
    }

    function testGas_snapshotAndClaim() public {
        vm.prank(owner);
        uint256 snapId = token.snapshot();

        vm.startPrank(owner);
        uint256 distId = dividends.createDistribution(address(usdc), 10_000e6, snapId);
        usdc.approve(address(dividends), 10_000e6);
        dividends.depositPayment(distId);
        vm.stopPrank();

        vm.prank(alice);
        dividends.claim(distId);
    }
}
