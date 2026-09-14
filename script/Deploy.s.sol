// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";

/// @notice Stub de deploy (Fase IDENT). Se ampliará en fases posteriores / SOLV.
contract Deploy is Script {
    uint256 internal constant TOPIC_KYC = 1;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer = pk != 0 ? vm.addr(pk) : msg.sender;

        if (pk != 0) vm.startBroadcast(pk);
        else vm.startBroadcast();

        ClaimTopicsRegistry topics = new ClaimTopicsRegistry(deployer);
        TrustedIssuersRegistry issuers = new TrustedIssuersRegistry(deployer);
        IdentityRegistry registry = new IdentityRegistry(deployer, address(topics), address(issuers));
        topics.addClaimTopic(TOPIC_KYC);

        vm.stopBroadcast();

        console2.log("ClaimTopicsRegistry", address(topics));
        console2.log("TrustedIssuersRegistry", address(issuers));
        console2.log("IdentityRegistry", address(registry));
    }
}
