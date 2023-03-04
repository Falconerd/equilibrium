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
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = rewardTokenA;
        rewardTokens[1] = rewardTokenB;
        uint[] memory amounts = new uint[](2);
        amounts[0] = 100_000;
        amounts[1] = 100_000;
        fixedPeriodMultiRewards.notifyRewardAmounts(rewardTokens, amounts);
//function notifyRewardAmounts(address[] calldata rewardsTokens, uint[] calldata amounts) external updateReward(address(0)) {
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
        assertEq(address(this), fixedPeriodMultiRewards.rewardsDistributor(rewardTokenA));
        assertEq(address(this), fixedPeriodMultiRewards.rewardsDistributor(rewardTokenB));
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
        fixture_SetupRewards();
        fixture_StartNextPeriod();
        assert(fixedPeriodMultiRewards.nextPeriodTime() >= fixedPeriodMultiRewards.contractDeployTime() + fixedPeriodMultiRewards.period());
    }

    function test_RewardPerTokenIsZeroIfNoSupply() public {
        fixture_SetupRewards();
        fixture_StartNextPeriod();
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_RewardPerTokenIsZeroIfNoPeriods() public {
        fixture_Deposit();
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_SetRewardRate() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod();

        assertEq(100_000 / fixedPeriodMultiRewards.period(), fixedPeriodMultiRewards.rewardRate(address(rewardTokenA)));
        assertEq(100_000 / fixedPeriodMultiRewards.period(), fixedPeriodMultiRewards.rewardRate(address(rewardTokenB)));

        assertEq(timestamp, fixedPeriodMultiRewards.lastRewardsUpdateTime());

        assertEq(timestamp + 6 hours, fixedPeriodMultiRewards.nextPeriodTime());
    }

    function test_RewardPerTokenFn() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod();

        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        assertEq(4, fixedPeriodMultiRewards.rewardRate(address(rewardTokenA)));

        vm.warp(timestamp + 60);

        assertEq(240, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
        assertEq(2.4e18, fixedPeriodMultiRewards.rewardPerToken(rewardTokenA));
    }

    function test_SingleUserGetReward() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod();

        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        vm.warp(timestamp + 60);

        assertEq(240, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
        assertEq(2.4e18, fixedPeriodMultiRewards.rewardPerToken(rewardTokenA));
        fixedPeriodMultiRewards.getReward();
        assertEq(240, IERC20(rewardTokenA).balanceOf(address(this)));
    }

    //function test_MultiUserGetReward() public {
    //    fixture_SetupRewards();

    //    //assertEq(50_000, rewardTokenA.balanceOf(address(fixedPeriodMultiRewards)));
    //    //assertEq(50_000, rewardTokenB.balanceOf(address(fixedPeriodMultiRewards)));

    //    //vm.prank(1337);
    //}
}
