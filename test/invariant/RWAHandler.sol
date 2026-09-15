// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {CountryRestrictModule} from "../../src/compliance/CountryRestrictModule.sol";
import {IdentityRegistry} from "../../src/IdentityRegistry.sol";
import {MaxBalanceModule} from "../../src/compliance/MaxBalanceModule.sol";
import {ModularCompliance} from "../../src/ModularCompliance.sol";
import {RWAToken} from "../../src/RWAToken.sol";

/// @notice Handler para invariantes: mint/transfer/freeze/forced/compliance updates.
contract RWAHandler is Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint16 internal constant COUNTRY_AR = 32;
    uint16 internal constant COUNTRY_US = 840;

    RWAToken public immutable token;
    IdentityRegistry public immutable registry;
    ModularCompliance public immutable compliance;
    CountryRestrictModule public immutable countryModule;
    MaxBalanceModule public immutable maxBalanceModule;

    address public immutable owner;
    address public immutable claimIssuer;
    address[] public actors;

    constructor(
        RWAToken token_,
        IdentityRegistry registry_,
        ModularCompliance compliance_,
        CountryRestrictModule countryModule_,
        MaxBalanceModule maxBalanceModule_,
        address owner_,
        address claimIssuer_,
        address[] memory actors_
    ) {
        token = token_;
        registry = registry_;
        compliance = compliance_;
        countryModule = countryModule_;
        maxBalanceModule = maxBalanceModule_;
        owner = owner_;
        claimIssuer = claimIssuer_;
        actors = actors_;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function sumBalances() public view returns (uint256 sum) {
        uint256 n = actors.length;
        for (uint256 i = 0; i < n; ++i) {
            sum += token.balanceOf(actors[i]);
        }
    }

    function frozenOk() public view returns (bool) {
        uint256 n = actors.length;
        for (uint256 i = 0; i < n; ++i) {
            if (token.getFrozenTokens(actors[i]) > token.balanceOf(actors[i])) return false;
        }
        return true;
    }

    function mint(uint256 actorSeed, uint256 amount) external {
        address to = actors[actorSeed % actors.length];
        amount = bound(amount, 1, 100 ether);
        uint256 maxBal = maxBalanceModule.maxBalance();
        uint256 bal = token.balanceOf(to);
        if (bal >= maxBal) return;
        uint256 room = maxBal - bal;
        if (amount > room) amount = room;
        if (amount == 0) return;

        vm.prank(owner);
        try token.mint(to, amount) {} catch {}
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;

        uint256 free = token.getFreeBalance(from);
        if (free == 0) return;
        amount = bound(amount, 1, free);

        vm.prank(from);
        try token.transfer(to, amount) {} catch {}
    }

    function freezePartial(uint256 actorSeed, uint256 amount) external {
        address account = actors[actorSeed % actors.length];
        uint256 free = token.getFreeBalance(account);
        if (free == 0) return;
        amount = bound(amount, 1, free);

        vm.prank(owner);
        try token.freezePartialTokens(account, amount) {} catch {}
    }

    function unfreezePartial(uint256 actorSeed, uint256 amount) external {
        address account = actors[actorSeed % actors.length];
        uint256 frozen = token.getFrozenTokens(account);
        if (frozen == 0) return;
        amount = bound(amount, 1, frozen);

        vm.prank(owner);
        try token.unfreezePartialTokens(account, amount) {} catch {}
    }

    function toggleFreeze(uint256 actorSeed, bool freeze) external {
        address account = actors[actorSeed % actors.length];
        vm.prank(owner);
        try token.setAddressFrozen(account, freeze) {} catch {}
    }

    function forcedTransfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;
        if (token.isFrozen(to)) return;

        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        vm.prank(owner);
        try token.forcedTransfer(from, to, amount) {} catch {}
    }

    function setMaxBalance(uint256 newMax) external {
        newMax = bound(newMax, 1 ether, 10_000 ether);
        vm.prank(owner);
        try maxBalanceModule.setMaxBalance(newMax) {} catch {}
    }

    function toggleCountryUS(bool restricted) external {
        vm.prank(owner);
        try countryModule.setCountryRestricted(COUNTRY_US, restricted) {} catch {}
    }
}
