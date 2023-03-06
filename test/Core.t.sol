// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../src/Core.sol";
import "../src/MockOracle.sol";
import "../src/MockGauge.sol";
import "../src/Token.sol";
import "../src/IDepositWithdraw.sol";
import "forge-std/Test.sol";

// Since this contract inherits FixedPeriodMultiRewards, only test
// Farm functions, not ones covered by the parent.
contract CoreTest is Test {
    uint startTimestamp;
    address depositToken;
    address rewardTokenA;
    address rewardTokenB;
    Core core;

    function setUp() public {
        depositToken = address(new Token("DEP", "DEP", 100_000e18));
        rewardTokenA = address(new Token("RWA", "RWA", 100_000e18));
        rewardTokenB = address(new Token("RWB", "RWB", 100_000e18));
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

    function test_DeployMultipleFarmsSetUpActiveFarms() public {
        address oracle = address(new MockOracle());
        address gauge = address(new MockGauge());
        address farm0 = core.deploy(depositToken, gauge, 0, oracle);
        address farm1 = core.deploy(depositToken, gauge, 1, oracle);
        address farm2 = core.deploy(depositToken, gauge, 2, oracle);
        address farm3 = core.deploy(depositToken, gauge, 3, oracle);

        MockGauge(gauge).setTokenById(0, depositToken);
        MockGauge(gauge).setTokenById(1, depositToken);
        MockGauge(gauge).setTokenById(2, depositToken);
        MockGauge(gauge).setTokenById(3, depositToken);

        address[4] memory activeFarms = [farm0, farm1, farm2, farm3];
        core.setActiveFarms(activeFarms);
        
        vm.warp(startTimestamp + 30 minutes);
        
        assertEq(0, core.score());
        assertEq(0, Farm(farm0).autoClaimedRewardsLength());
        assertEq(0, Farm(farm0).rewardTokensLength());

        IERC20(depositToken).approve(farm0, type(uint).max);
        IERC20(depositToken).approve(farm1, type(uint).max);
        IERC20(depositToken).approve(farm2, type(uint).max);
        IERC20(depositToken).approve(farm3, type(uint).max);

        IDepositWithdraw(farm0).deposit(10e18);
        IDepositWithdraw(farm1).deposit(10e18);
        IDepositWithdraw(farm2).deposit(10e18);
        IDepositWithdraw(farm3).deposit(10e18);

        int lastScore = core.score();

        vm.warp(startTimestamp + 30 minutes);
        IDepositWithdraw(farm0).withdraw(1e18);
        vm.warp(startTimestamp + 60 minutes);
        IDepositWithdraw(farm1).withdraw(1e18);
        vm.warp(startTimestamp + 90 minutes);
        IDepositWithdraw(farm2).withdraw(1e18);
        vm.warp(startTimestamp + 120 minutes);
        IDepositWithdraw(farm3).withdraw(1e18);

        assertGt(core.score(), lastScore);
        lastScore = core.score();

        vm.warp(startTimestamp + 150 minutes);
        IDepositWithdraw(farm0).withdraw(1e18);
        vm.warp(startTimestamp + 180 minutes);
        IDepositWithdraw(farm1).withdraw(1e18);
        vm.warp(startTimestamp + 210 minutes);
        IDepositWithdraw(farm2).withdraw(1e18);
        vm.warp(startTimestamp + 240 minutes);
        IDepositWithdraw(farm3).withdraw(1e18);

        assertGt(core.score(), lastScore);
        lastScore = core.score();

        vm.warp(startTimestamp + 300 minutes);
        IDepositWithdraw(farm0).deposit(30e18);
        IDepositWithdraw(farm1).withdraw(6e18);
        IDepositWithdraw(farm2).deposit(90e18);
        IDepositWithdraw(farm3).deposit(400e18);

        assertLt(core.score(), lastScore);
    }
}

