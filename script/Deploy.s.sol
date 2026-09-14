// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @notice Deploy identity + RWAToken + DividendDistributor (+ Mock USDC lab).
contract Deploy is Script {
    uint256 internal constant TOPIC_KYC = 1;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer = pk != 0 ? vm.addr(pk) : msg.sender;

        string memory name_ = vm.envOr("TOKEN_NAME", string("RWA Real Estate"));
        string memory symbol_ = vm.envOr("TOKEN_SYMBOL", string("rRE"));

        if (pk != 0) vm.startBroadcast(pk);
        else vm.startBroadcast();

        ClaimTopicsRegistry topics = new ClaimTopicsRegistry(deployer);
        TrustedIssuersRegistry issuers = new TrustedIssuersRegistry(deployer);
        IdentityRegistry registry = new IdentityRegistry(deployer, address(topics), address(issuers));
        topics.addClaimTopic(TOPIC_KYC);

        RWAToken token = new RWAToken(name_, symbol_, deployer, address(registry));
        DividendDistributor dividends = new DividendDistributor(deployer, address(token));
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.stopBroadcast();

        console2.log("ClaimTopicsRegistry", address(topics));
        console2.log("TrustedIssuersRegistry", address(issuers));
        console2.log("IdentityRegistry", address(registry));
        console2.log("RWAToken", address(token));
        console2.log("DividendDistributor", address(dividends));
        console2.log("MockUSDC", address(usdc));
    }
}
