// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../src/FixedPeriodMultiRewards.sol";
import "../src/Token.sol";
import "../src/Dummy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract FixedPeriodMultiRewardsTest is Test {
    uint startTimestamp;
    FixedPeriodMultiRewards fixedPeriodMultiRewards;
    address depositToken;
    address rewardTokenA;
    address rewardTokenB;
    address dummyHolder = address(new Dummy());

    function setUp() public {
        startTimestamp = block.timestamp;

        depositToken = address(new Token("DepositToken", "DT", 100_000));
        rewardTokenA = address(new Token("RewardTokenA", "RTA", 100_000));
        rewardTokenB = address(new Token("RewardTokenB", "RTB", 100_000));

        fixedPeriodMultiRewards = new FixedPeriodMultiRewards(IERC20(depositToken), 6 hours, "FarmToken", "FT");
    }

    // Fixtures

    function fixture_AddRewardTokens() internal {
        fixedPeriodMultiRewards.addReward(rewardTokenA, address(this));
        fixedPeriodMultiRewards.addReward(rewardTokenB, address(this));
    }

    function fixture_Deposit() internal {
        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);
    }

    function fixture_SetPeriodStarterToThisContract() internal {
        fixedPeriodMultiRewards.setPeriodStarter(address(this));
    }

    function fixture_StartNextPeriod() internal {
        fixture_SetPeriodStarterToThisContract();
        fixedPeriodMultiRewards.startNextPeriod();
    }

    function fixture_SetupRewards() internal {
        fixture_AddRewardTokens();

        // Deposit rewards for next period.
        IERC20(rewardTokenA).transfer(dummyHolder, 100_000);
        IERC20(rewardTokenB).transfer(dummyHolder, 100_000);

        // Set up reward distributors.
        fixedPeriodMultiRewards.setRewardsDistributor(rewardTokenA, dummyHolder);
        fixedPeriodMultiRewards.setRewardsDistributor(rewardTokenB, dummyHolder);

        // Dummy allows this contract to spend tokens.
        Dummy(dummyHolder).approve(address(fixedPeriodMultiRewards), rewardTokenA, IERC20(rewardTokenA).balanceOf(address(dummyHolder)));
        Dummy(dummyHolder).approve(address(fixedPeriodMultiRewards), rewardTokenB, IERC20(rewardTokenB).balanceOf(address(dummyHolder)));
    }

    // Tests

    function test_Deployment() public {
        assertEq(startTimestamp, fixedPeriodMultiRewards.contractDeployTime());
        assertEq(0, fixedPeriodMultiRewards.lastRewardsUpdateTime());
        assertEq(0, fixedPeriodMultiRewards.nextPeriodTime());
    }

    function test_AddRewardTokens() public {
        fixture_AddRewardTokens();
        assertEq(rewardTokenA, address(fixedPeriodMultiRewards.rewardTokens(0)));
        assertEq(rewardTokenB, address(fixedPeriodMultiRewards.rewardTokens(1)));
        assertEq(address(this), fixedPeriodMultiRewards.rewardsDistributorByRewardsToken(rewardTokenA));
        assertEq(address(this), fixedPeriodMultiRewards.rewardsDistributorByRewardsToken(rewardTokenB));
    }

    function test_Deposit() public {
        fixture_Deposit();
        assertEq(100, IERC20(fixedPeriodMultiRewards).balanceOf(address(this)));
        assertEq(100, IERC20(fixedPeriodMultiRewards).totalSupply());
    }

    function test_Withdraw() public {
        fixture_Deposit();
        fixedPeriodMultiRewards.withdraw(100);
        assertEq(0, IERC20(fixedPeriodMultiRewards).balanceOf(address(this)));
        assertEq(0, IERC20(fixedPeriodMultiRewards).totalSupply());
    }

    function test_StartNextPeriod() public {
        fixture_StartNextPeriod();
        assert(fixedPeriodMultiRewards.nextPeriodTime() >= fixedPeriodMultiRewards.contractDeployTime() + fixedPeriodMultiRewards.period());
    }

    function test_RewardPerTokenIsZeroIfNoSupply() public {
        fixture_StartNextPeriod();
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_RewardPerTokenIsZeroIfNoPeriods() public {
        fixture_Deposit();
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_SetRewardRate() public {
        uint timestamp = startTimestamp + 1337;
        vm.warp(timestamp);

        fixture_SetupRewards();
        fixture_StartNextPeriod();

        FixedPeriodMultiRewards.RewardHistory memory historyA = fixedPeriodMultiRewards.getRewardHistory(rewardTokenA, 0);
        FixedPeriodMultiRewards.RewardHistory memory historyB = fixedPeriodMultiRewards.getRewardHistory(rewardTokenB, 0);

        assertEq(100_000 / fixedPeriodMultiRewards.period(), historyA.rewardRate);
        assertEq(100_000 / fixedPeriodMultiRewards.period(), historyB.rewardRate);

        assertEq(timestamp, historyA.timestamp);
        assertEq(timestamp, historyB.timestamp);

        assertEq(timestamp + 6 hours, fixedPeriodMultiRewards.nextPeriodTime());
    }

    function test_RewardPerToken() public {
        uint timestamp = startTimestamp + 69420;
        vm.warp(timestamp);

        fixture_SetupRewards();
        fixture_StartNextPeriod();

        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        FixedPeriodMultiRewards.RewardHistory memory historyA = fixedPeriodMultiRewards.getRewardHistory(rewardTokenA, 0);
        assertEq(4, historyA.rewardRate);

        vm.warp(timestamp + 60);

        assertEq(123, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
        assertEq(123, fixedPeriodMultiRewards.rewardPerToken(rewardTokenA));
    }

    //function test_SingleUserGetReward() public {
    //    uint timestamp = startTimestamp + 69420;
    //    vm.warp(timestamp);

    //    fixture_SetupRewards();
    //    fixture_StartNextPeriod();

    //    IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
    //    fixedPeriodMultiRewards.deposit(100);

    //    vm.warp(timestamp + 3 hours);

    //    //fixedPeriodMultiRewards.getReward();

    //    //uint x = 4 * 3 hours;
    //    //assertEq(32, x);

    //    assertEq(42, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));

    //    //assertEq(42, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
    //}

    //function test_SingleUserGetReward() public {
    //    fixture_SetupRewards();
    //    fixture_StartNextPeriod();

    //    assertEq(50_000, IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards)));
    //    assertEq(50_000, IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards)));

    //    fixture_Deposit();

    //    skip(3 hours);
    ////function rewardPerToken(address rewardsToken) public view returns (uint) {

    //    assertEq(333, fixedPeriodMultiRewards.rewardPerToken(rewardTokenA));
    //    fixedPeriodMultiRewards.touch();

    //    skip(3 hours);

    //    assertEq(666, fixedPeriodMultiRewards.earned(rewardTokenA, address(this)));
    //    FixedPeriodMultiRewards.RewardHistory memory h = fixedPeriodMultiRewards.getRewardHistory(rewardTokenA, 0);
    //    assertEq(222, h.rewardRate);
    //    //fixedPeriodMultiRewards.getReward();

    //    //assertEq(50_000, rewardTokenA.balanceOf(address(this)));
    //    //assertEq(50_000, rewardTokenB.balanceOf(address(this)));
    //}

    //function test_MultiUserGetReward() public {
    //    fixture_SetupRewards();

    //    //assertEq(50_000, rewardTokenA.balanceOf(address(fixedPeriodMultiRewards)));
    //    //assertEq(50_000, rewardTokenB.balanceOf(address(fixedPeriodMultiRewards)));

    //    //vm.prank(1337);
    //}
}
