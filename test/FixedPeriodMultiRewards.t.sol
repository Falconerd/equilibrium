// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../src/FixedPeriodMultiRewards.sol";
import "../src/Token.sol";
import "../src/RewardsDistributor.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract FixedPeriodMultiRewardsTest is Test {
    uint startTimestamp;
    FixedPeriodMultiRewards fixedPeriodMultiRewards;
    address depositToken;
    address rewardTokenA;
    address rewardTokenB;
    address rewardsDistributor = address(new RewardsDistributor());

    function setUp() public {
        startTimestamp = block.timestamp;

        depositToken = address(new Token("DepositToken", "DT", 1_000_000_000e18));
        rewardTokenA = address(new Token("RewardTokenA", "RTA", 1_000_000_000e18));
        rewardTokenB = address(new Token("RewardTokenB", "RTB", 1_000_000_000e18));

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

    function fixture_StartNextPeriod(uint amountA, uint amountB) internal {
        fixture_SetPeriodStarterToThisContract();
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = rewardTokenA;
        rewardTokens[1] = rewardTokenB;
        uint[] memory amounts = new uint[](2);
        amounts[0] = amountA;
        amounts[1] = amountB;

        IRewardsDistributor(fixedPeriodMultiRewards.rewardsDistributor(rewardTokenA))
            .setNextAmountToDistribute(rewardTokenA, amountA);
        IRewardsDistributor(fixedPeriodMultiRewards.rewardsDistributor(rewardTokenB))
            .setNextAmountToDistribute(rewardTokenB, amountB);
        fixedPeriodMultiRewards.startNextPeriod();
    }

    function fixture_SetupRewards() internal {
        fixture_AddRewardTokens();

        // Deposit rewards for next period.
        IERC20(rewardTokenA).transfer(rewardsDistributor, 1_000_000_000e18);
        IERC20(rewardTokenB).transfer(rewardsDistributor, 1_000_000_000e18);

        // Set up reward distributors.
        fixedPeriodMultiRewards.setRewardsDistributor(rewardTokenA, rewardsDistributor);
        fixedPeriodMultiRewards.setRewardsDistributor(rewardTokenB, rewardsDistributor);

        // RewardsDistributor allows this contract to spend tokens.
        RewardsDistributor(rewardsDistributor).approve(address(fixedPeriodMultiRewards), rewardTokenA, IERC20(rewardTokenA).balanceOf(address(rewardsDistributor)));
        RewardsDistributor(rewardsDistributor).approve(address(fixedPeriodMultiRewards), rewardTokenB, IERC20(rewardTokenB).balanceOf(address(rewardsDistributor)));
    }

    // Tests

    function test_Deployment() public {
        assertEq(startTimestamp, fixedPeriodMultiRewards.contractDeployTime());
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
        fixture_StartNextPeriod(0, 0);
        assert(fixedPeriodMultiRewards.nextPeriodTime() >= fixedPeriodMultiRewards.contractDeployTime() + fixedPeriodMultiRewards.period());
    }

    function test_RewardPerTokenIsZeroIfNoSupply() public {
        fixture_SetupRewards();
        fixture_StartNextPeriod(0, 0);
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_RewardPerTokenIsZeroIfNoPeriods() public {
        fixture_Deposit();
        assertEq(0, fixedPeriodMultiRewards.rewardPerToken(address(0)));
    }

    function test_SetRewardRate() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod(100_000e18, 100_000e18);

        assertEq(100_000e18 / fixedPeriodMultiRewards.period(), fixedPeriodMultiRewards.rewardRate(address(rewardTokenA)));
        assertEq(100_000e18 / fixedPeriodMultiRewards.period(), fixedPeriodMultiRewards.rewardRate(address(rewardTokenB)));

        assertEq(timestamp + 6 hours, fixedPeriodMultiRewards.nextPeriodTime());
    }

    function test_MultiUserGetReward() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod(100_000e18, 100_000e18);

        assertEq(100_000e18, IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards)));
        assertEq(100_000e18, IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards)));

        // Deposit from user 1 (this contract)
        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        IERC20(depositToken).transfer(address(1337), 100);

        // Deposit from user 2
        startHoax(address(1337));

        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        vm.stopPrank();

        vm.warp(timestamp + 60);

        uint expectedRewardRate = IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards)) / 6 hours;
        uint expectedEarned = expectedRewardRate * 60 / 2;

        assertEq(expectedRewardRate, fixedPeriodMultiRewards.rewardRate(rewardTokenA));

        assertApproxEqAbs(expectedEarned, fixedPeriodMultiRewards.earned(address(this), rewardTokenA), 1e2, "reward rate 0");
        assertApproxEqAbs(expectedEarned, fixedPeriodMultiRewards.earned(address(this), rewardTokenB), 1e2, "reward rate 1");
        assertApproxEqAbs(expectedEarned, fixedPeriodMultiRewards.earned(address(1337), rewardTokenA), 1e2, "reward rate 2");
        assertApproxEqAbs(expectedEarned, fixedPeriodMultiRewards.earned(address(1337), rewardTokenB), 1e2, "reward rate 3");

        vm.warp(timestamp + fixedPeriodMultiRewards.period());

        fixedPeriodMultiRewards.getReward();
        hoax(address(1337));
        fixedPeriodMultiRewards.getReward();

        uint balanceBeforeA = IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards));
        uint balanceBeforeB = IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards));

        fixture_StartNextPeriod(69_420e18, 42_690e18);

        uint expectedBalanceA = 69_420e18 + balanceBeforeA;
        uint expectedBalanceB = 42_690e18 + balanceBeforeB;

        assertApproxEqAbs(expectedBalanceA, IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards)), 1e3, "balance");
        assertApproxEqAbs(expectedBalanceB, IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards)), 1e3, "balance");

        uint expectedRewardRateA = expectedBalanceA / fixedPeriodMultiRewards.period();
        uint expectedRewardRateB = expectedBalanceB / fixedPeriodMultiRewards.period();

        vm.warp(timestamp + fixedPeriodMultiRewards.period() + 60);

        assertApproxEqAbs(expectedRewardRateA, fixedPeriodMultiRewards.rewardRate(rewardTokenA), 1e3, "reward rate");
        assertApproxEqAbs(expectedRewardRateB, fixedPeriodMultiRewards.rewardRate(rewardTokenB), 1e3, "reward rate");

        uint expectedEarnedA = expectedRewardRateA * 60 / 2;
        uint expectedEarnedB = expectedRewardRateB * 60 / 2;

        assertApproxEqAbs(expectedEarnedA, fixedPeriodMultiRewards.earned(address(this), rewardTokenA), 1e3);
        assertApproxEqAbs(expectedEarnedB, fixedPeriodMultiRewards.earned(address(this), rewardTokenB), 1e3);
    }
}
