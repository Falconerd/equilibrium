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
        fixedPeriodMultiRewards.notifyRewardAmounts(rewardTokens, amounts);
    }

    function fixture_SetupRewards() internal {
        fixture_AddRewardTokens();

        // Deposit rewards for next period.
        IERC20(rewardTokenA).transfer(dummyHolder, 1_000_000_000e18);
        IERC20(rewardTokenB).transfer(dummyHolder, 1_000_000_000e18);

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

        assertEq(timestamp, fixedPeriodMultiRewards.lastRewardsUpdateTime());

        assertEq(timestamp + 6 hours, fixedPeriodMultiRewards.nextPeriodTime());
    }

    function test_RewardPerTokenFn() public {
        uint timestamp = block.timestamp;

        fixture_SetupRewards();
        fixture_StartNextPeriod(100_000e18, 100_000e18);

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
        fixture_StartNextPeriod(100_000e18, 100_000e18);

        IERC20(depositToken).approve(address(fixedPeriodMultiRewards), 100);
        fixedPeriodMultiRewards.deposit(100);

        vm.warp(timestamp + 60);

        assertEq(240, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
        assertEq(2.4e18, fixedPeriodMultiRewards.rewardPerToken(rewardTokenA));
        fixedPeriodMultiRewards.getReward();
        assertEq(240, IERC20(rewardTokenA).balanceOf(address(this)));
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

        assertEq(120, fixedPeriodMultiRewards.earned(address(this), rewardTokenA));
        assertEq(120, fixedPeriodMultiRewards.earned(address(this), rewardTokenB));
        assertEq(120, fixedPeriodMultiRewards.earned(address(1337), rewardTokenA));
        assertEq(120, fixedPeriodMultiRewards.earned(address(1337), rewardTokenB));

        vm.warp(timestamp + fixedPeriodMultiRewards.period());

        fixedPeriodMultiRewards.getReward();
        hoax(address(1337));
        fixedPeriodMultiRewards.getReward();

        uint balanceBeforeA = IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards));
        uint balanceBeforeB = IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards));

        fixture_StartNextPeriod(69_420e18, 42_690e18);

        uint expectedBalanceA = 69_420e18 + balanceBeforeA;
        uint expectedBalanceB = 42_690e18 + balanceBeforeB;

        assertEq(expectedBalanceA, IERC20(rewardTokenA).balanceOf(address(fixedPeriodMultiRewards)));
        assertEq(expectedBalanceB, IERC20(rewardTokenB).balanceOf(address(fixedPeriodMultiRewards)));
        assertEq(expectedBalanceB, 1234);

        uint expectedRewardRateA = expectedBalanceA / fixedPeriodMultiRewards.period();
        uint expectedRewardRateB = expectedBalanceB / fixedPeriodMultiRewards.period();

        assertEq(expectedRewardRateA, 1234);
        assertEq(expectedRewardRateB, 1234);

        vm.warp(timestamp + fixedPeriodMultiRewards.period() + 60);

        assertEq(expectedRewardRateA, fixedPeriodMultiRewards.rewardRate(rewardTokenA), "reward rate");
        assertEq(expectedRewardRateB, fixedPeriodMultiRewards.rewardRate(rewardTokenB), "reward rate");

        uint expectedEarnedA = expectedRewardRateA * 60 / 2;
        uint expectedEarnedB = expectedRewardRateB * 60 / 2;

        assertApproxEqAbs(expectedEarnedA, fixedPeriodMultiRewards.earned(address(this), rewardTokenA), 2e18);
        assertApproxEqAbs(expectedEarnedB, fixedPeriodMultiRewards.earned(address(this), rewardTokenB), 2e18);
    }
}
