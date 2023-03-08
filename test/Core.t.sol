// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20} from "../src/ERC20.sol";
import {Ownable} from "../src/Ownable.sol";
import {Token} from "../src/Token.sol";
import {StakedToken} from "../src/StakedToken.sol";
import {Core} from "../src/Core.sol";
import {MockPair} from "../src/MockPair.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {Distributor} from "../src/Distributor.sol";
import {Farm} from "../src/Farm.sol";
import {FixedPeriodMultiRewards} from "../src/FixedPeriodMultiRewards.sol";
import "forge-std/Test.sol";

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

contract CoreTest is Test {
    using UQ112x112 for uint224;

    address houseToken;
    address stakedToken;
    address core;
    address fakeLP0;
    address fakeLP1;
    address fakeLP2;
    address fakeLP3;
    address oracle;
    address farm0;
    address farm1;
    address farm2;
    address farm3;
    address admin = address(1337);

    function setUp() public {
        houseToken = address(new Token());
        stakedToken = address(new StakedToken(houseToken));
        core = address(new Core(houseToken, stakedToken, admin));
        fakeLP0 = address(new MockPair("FakeLP0", "FakeLP0"));
        fakeLP1 = address(new MockPair("FakeLP1", "FakeLP1"));
        fakeLP2 = address(new MockPair("FakeLP2", "FakeLP2"));
        fakeLP3 = address(new MockPair("FakeLP3", "FakeLP3"));
        oracle = address(new MockOracle());
    }

    function test_E2E() public {
        bytes32 salt = 0xdd2FB1EE6f83F3f072a6489f4A6DBaFa92FB1EE6f83F3f072a6489f4A6DBaFa9;
        farm0 = Core(core).deployFarm(salt, fakeLP0, address(0), 0, oracle);
        farm1 = Core(core).deployFarm(salt, fakeLP1, address(0), 0, oracle);
        farm2 = Core(core).deployFarm(salt, fakeLP2, address(0), 0, oracle);
        farm3 = Core(core).deployFarm(salt, fakeLP3, address(0), 0, oracle);

        // Send all houseToken to Core.
        IERC20(houseToken).transfer(core, IERC20(houseToken).totalSupply());

        address distributor0 = address(new Distributor(farm0));
        address distributor1 = address(new Distributor(farm1));
        address distributor2 = address(new Distributor(farm2));
        address distributor3 = address(new Distributor(farm3));

        Core(core).registerRewardToken(farm0, houseToken, distributor0);
        Core(core).registerRewardToken(farm1, houseToken, distributor1);
        Core(core).registerRewardToken(farm2, houseToken, distributor2);
        Core(core).registerRewardToken(farm3, houseToken, distributor3);

        Distributor(distributor0).approve(farm0, houseToken, type(uint).max);
        Distributor(distributor1).approve(farm1, houseToken, type(uint).max);
        Distributor(distributor2).approve(farm2, houseToken, type(uint).max);
        Distributor(distributor3).approve(farm3, houseToken, type(uint).max);

        address distributorStaked = address(new Distributor(stakedToken));
        Farm(stakedToken).registerRewardToken(houseToken, distributorStaked);

        Distributor(distributorStaked).approve(stakedToken, houseToken, type(uint).max);
        Ownable(stakedToken).transferOwnership(core);

        assertEq(address(Core(core).farms(0)), farm0);
        assertEq(address(Core(core).farms(1)), farm1);
        assertEq(address(Core(core).farms(2)), farm2);
        assertEq(address(Core(core).farms(3)), farm3);

        assertEq(Core(core).farmIdByDepositToken(fakeLP0), 0);
        assertEq(Core(core).farmIdByDepositToken(fakeLP1), 1);
        assertEq(Core(core).farmIdByDepositToken(fakeLP2), 2);
        assertEq(Core(core).farmIdByDepositToken(fakeLP3), 3);

        Core(core).setActiveFarms([farm0, farm1, farm2, farm3]);
        Core(core).startEpoch();
        uint totalEmissionsThisEpoch =
            IERC20(houseToken).balanceOf(farm0) +
            IERC20(houseToken).balanceOf(farm1) +
            IERC20(houseToken).balanceOf(farm2) +
            IERC20(houseToken).balanceOf(farm3) +
            IERC20(houseToken).balanceOf(stakedToken) +
            IERC20(houseToken).balanceOf(admin);

        assertApproxEqAbs(Core(core).minEmissionsPerEpoch(), totalEmissionsThisEpoch, 1e8);

        // Test usage

        MockPair(fakeLP0).mint(100_000e18);
        MockPair(fakeLP1).mint(100_000e18);
        MockPair(fakeLP2).mint(100_000e18);
        MockPair(fakeLP3).mint(100_000e18);
        
        IERC20(fakeLP0).approve(farm0, 100_000e18);
        IERC20(fakeLP1).approve(farm1, 100_000e18);
        IERC20(fakeLP2).approve(farm2, 100_000e18);
        IERC20(fakeLP3).approve(farm3, 100_000e18);
        
        int scoreBefore = Core(core).score();
        Farm(farm0).deposit(99e18); // 99
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm1).deposit(100e18);
        Farm(farm0).deposit(1e18); // 100
        
        assertEq(100e18, Farm(farm0).totalValueLocked());
        
        int scoreNow = Core(core).score();
        assertGt(scoreBefore, scoreNow); // Goes from 0 to -50
        
        scoreBefore = scoreNow;
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm2).deposit(100e18);
        scoreNow = Core(core).score();
        assertGt(scoreNow, scoreBefore);
        
        scoreBefore = scoreNow;
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm3).deposit(100e18);
        scoreNow = Core(core).score();
        assertGt(scoreNow, scoreBefore);
        
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm0).withdraw(1e18); // 99
        scoreNow = Core(core).score();
        assertGt(scoreNow, scoreBefore);
        
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm1).withdraw(1e18);
        scoreNow = Core(core).score();
        assertGt(scoreNow, scoreBefore);
        
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm2).withdraw(1e18);
        scoreNow = Core(core).score();
        Farm(farm2).deposit(1e18);
        assertGt(scoreNow, scoreBefore);
        
        vm.warp(block.timestamp + 30 minutes);
        Farm(farm3).withdraw(1e18);
        scoreNow = Core(core).score();
        assertGt(scoreNow, scoreBefore);
        
        vm.warp(block.timestamp + 30 minutes);
        
        Farm(farm0).withdraw(1e17); // 98.9
        
        vm.warp(block.timestamp + 30 minutes);
        
        Farm(farm0).withdraw(1e17); // 98.8
        
        vm.warp(block.timestamp + 30 minutes);
        
        Farm(farm0).withdraw(1e17); // 98.7
        
        // TVL is time weighted, so should be roughly 987e17
        assertApproxEqAbs(987e17, Farm(farm0).totalValueLocked(), 1e18);
        
        vm.warp(block.timestamp + 2 * 30 minutes);
        
        // Make sure the rewards are in range.
        Core(core).startEpoch();
        
        assertGt(Farm(farm0).rewardRate(houseToken) * 6 hours, uint(UQ112x112.encode(uint112(Core(core).minEmissionsPerEpoch())).uqdiv(uint112(1e20 / uint(Core(core).SHARES_FARMS()))) / 5192296858534827));
        assertLt(Farm(farm0).rewardRate(houseToken) * 6 hours, uint(UQ112x112.encode(uint112(Core(core).maxEmissionsPerEpoch())).uqdiv(uint112(1e20 / uint(Core(core).SHARES_FARMS()))) / 5192296858534827));

        Farm(farm0).getReward();
        uint user1Earned0 = IERC20(houseToken).balanceOf(address(this));
        assertApproxEqAbs(uint(UQ112x112.encode(uint112(Core(core).minEmissionsPerEpoch())).uqdiv(uint112(1e20 / uint(Core(core).SHARES_FARMS()))) / 5192296858534827), IERC20(houseToken).balanceOf(address(this)), 1e8);

        // User 2 should receive half as many rewards
        startHoax(address(69420));
        
        MockPair(fakeLP2).mint(100_000e18);
        IERC20(fakeLP2).approve(farm2, 100_000e18);
        Farm(farm2).deposit(50e18);
        
        vm.warp(block.timestamp + 3 hours);
        
        uint user1Earned = Farm(farm2).earned(address(this), houseToken);
        uint user2Earned = Farm(farm2).earned(address(69420), houseToken);
        
        assertEq(user1Earned, 2 * user2Earned);
        
        vm.stopPrank();
        
        Farm(farm2).getReward();
        assertEq(user1Earned + user1Earned0, IERC20(houseToken).balanceOf(address(this)));
        
        // Test StakedToken.
        uint minEmissionsPerEpochStaked = uint(UQ112x112.encode(uint112(Core(core).minEmissionsPerEpoch())).uqdiv(uint112(1e20 / uint(Core(core).SHARES_VAULT()))) / 5192296858534827);
        uint maxEmissionsPerEpochStaked = uint(UQ112x112.encode(uint112(Core(core).maxEmissionsPerEpoch())).uqdiv(uint112(1e20 / uint(Core(core).SHARES_VAULT()))) / 5192296858534827);
        assertGt(StakedToken(stakedToken).rewardRate(houseToken) * 6 hours, minEmissionsPerEpochStaked);
        assertLt(StakedToken(stakedToken).rewardRate(houseToken) * 6 hours, maxEmissionsPerEpochStaked);
        
        IERC20(houseToken).approve(stakedToken, 1e12);
        StakedToken(stakedToken).deposit(1e12);
        
        vm.warp(block.timestamp + 3 hours);
        
        assertGt(StakedToken(stakedToken).earned(address(this), houseToken), minEmissionsPerEpochStaked);
        assertLt(StakedToken(stakedToken).earned(address(this), houseToken), maxEmissionsPerEpochStaked);
    }
}
