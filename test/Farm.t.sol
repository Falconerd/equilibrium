// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../src/Token.sol";
import "../src/MockGauge.sol";
import "../src/MockOracle.sol";
import "../src/RewardsDistributor.sol";
import "../src/Farm.sol";
import "../src/FixedPeriodMultiRewards.sol";
import "forge-std/Test.sol";

// Since this contract inherits FixedPeriodMultiRewards, only test
// Farm functions, not ones covered by the parent.
contract FarmTest is Test {
    uint startTimestamp;
    Farm farm;
    address depositToken;
    address rewardTokenA;
    address rewardTokenB;
    address distributor = address(new RewardsDistributor());
    address mockGauge = address(new MockGauge());
    address oracle = address(new MockOracle());
    uint gaugeId = 0;

    function setUp() public {
        startTimestamp = block.timestamp;
        depositToken = address(new Token("DepositToken", "DT", 1_000_000_000e18));
        rewardTokenA = address(new Token("RewardTokenA", "RTA", 1_000_000_000e18));
        rewardTokenB = address(new Token("RewardTokenB", "RTB", 1_000_000_000e18));

        MockGauge(mockGauge).setTokenById(0, depositToken);

        farm = new Farm(IERC20(depositToken), IGauge(mockGauge), IOracle(oracle), gaugeId, 6 hours, "FarmToken", "FT");
    }

    function test_AutoClaimedRewards() public {
        farm.addReward(rewardTokenA, distributor);
        farm.addAutoClaimedReward(rewardTokenA);

        assert(farm.autoClaimedRewardsAdded(rewardTokenA));
    }
}

