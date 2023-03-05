// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../src/Core.sol";
import "../src/MockOracle.sol";
import "../src/MockGauge.sol";
import "../src/Token.sol";
import "forge-std/Test.sol";

// Since this contract inherits FixedPeriodMultiRewards, only test
// Farm functions, not ones covered by the parent.
contract FarmTest is Test {
    uint startTimestamp;
    address depositToken;
    Core core;

    function setUp() public {
        depositToken = address(new Token("DEP", "DEP", 100_000e18));
        core = new Core();
    }

    function test_DeployFarm() public {
        address oracle = address(new MockOracle());
        address gauge = address(new MockGauge());
        address farm = core.deploy(depositToken, gauge, 0, oracle);

        assertEq(core.farms(0), farm);
        assertEq(core.farmIdByAddress(farm), 0);
        assertEq(core.farmIdByDepositToken(depositToken), core.farmIdByAddress(farm));
        assert(address(0) != core.defaultDistributor(farm));
    }
}

