import { expect } from "chai";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

describe("Farm contract", function () {
    async function deployFarmFixture() {
        const Token = await ethers.getContractFactory("Token");
        const Farm = await ethers.getContractFactory("Farm");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const stakingToken = await Token.deploy("ETH", "ETH", 18, 1000);
        const rewardsToken = await Token.deploy("RWD", "RWD", 18, 2e12);
        await stakingToken.deployed();
        await rewardsToken.deployed();

        const farm = await Farm.deploy(stakingToken.address, rewardsToken.address);
        await farm.deployed();

        return { farm, stakingToken, rewardsToken, owner, addr1, addr2 };
    }

    describe("Deployment", function () {
        async function stakeTokenFixture() {
            const { farm, stakingToken, rewardsToken, owner, addr1, addr2 } = await loadFixture(deployFarmFixture);
            await expect(stakingToken.transfer(addr1.address, 100)).to.changeTokenBalances(stakingToken, [owner, addr1], [-100, 100]);
            expect(await stakingToken.balanceOf(addr1.address)).to.equal(100);
            await expect(stakingToken.transfer(addr2.address, 100)).to.changeTokenBalances(stakingToken, [owner, addr2], [-100, 100]);
            expect(await stakingToken.balanceOf(addr2.address)).to.equal(100);

            await rewardsToken.transfer(farm.address, 2e12);

            return { farm, stakingToken, rewardsToken, owner, addr1, addr2 };
        }
        
        it("Should deploy with 0 starting tokens", async function () {
            const { farm } = await loadFixture(deployFarmFixture);
            expect(await farm.totalSupply()).to.equal(0);
        });

        it("Should be able to stake tokens", async function () {
            const { farm, stakingToken, addr1 } = await loadFixture(stakeTokenFixture);
            await stakingToken.connect(addr1).approve(farm.address, 100);
            await farm.connect(addr1).stake(100);
            expect(await farm.balanceOf(addr1.address)).to.equal(100);
        });

        it("Should be increase the reward when staked", async function () {
            const { farm, stakingToken, rewardsToken, addr1, addr2 } = await loadFixture(stakeTokenFixture);
            const ONE_WEEK_IN_SECONDS = BigNumber.from(7 * 24 * 60 * 60);
            const HALF_ONE_WEEK_IN_SECONDS = ONE_WEEK_IN_SECONDS.div(2);

            const startTime = BigNumber.from(await time.latest());
            const halfTime = startTime.add(HALF_ONE_WEEK_IN_SECONDS);
            const endTime = startTime.add(ONE_WEEK_IN_SECONDS);

            await farm.setRewardsDuration(ONE_WEEK_IN_SECONDS);
            await farm.notifyRewardAmount(1e12);

            await stakingToken.connect(addr1).approve(farm.address, 100);
            await farm.connect(addr1).stake(100);
            expect(await farm.balanceOf(addr1.address)).to.equal(100);

            await time.increaseTo(halfTime);
            expect(await time.latest()).to.equal(halfTime);

            await stakingToken.connect(addr2).approve(farm.address, 100);
            await farm.connect(addr2).stake(100);
            expect(await farm.balanceOf(addr2.address)).to.equal(100);

            await time.increaseTo(endTime);

            expect(await time.latest()).to.equal(endTime);

            expect(await farm.earned(addr2.address)).to.closeTo(.25e12, BigInt("10000000"));
            expect(await farm.earned(addr1.address)).to.closeTo(.75e12, BigInt("10000000"));

            await farm.connect(addr1).getReward();
            expect(await rewardsToken.balanceOf(addr1.address)).to.closeTo(.75e12, BigInt("10000000"));

            await time.increase(100);
            await farm.balanceOf(addr1.address);
            await time.increase(100);

            await farm.setRewardsDuration(ONE_WEEK_IN_SECONDS);
            await farm.notifyRewardAmount(1e12);
        });
    });
});
