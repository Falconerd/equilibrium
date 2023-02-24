import { expect } from "chai";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

const SIX_HOURS_IN_SECONDS = 60 * 60 * 6;

describe("Core contract", function () {
    async function deployFixture() {
        const Core = await ethers.getContractFactory("Core");
        const Token = await ethers.getContractFactory("Token");
        const Farm = await ethers.getContractFactory("Farm");
        const Oracle = await ethers.getContractFactory("Oracle");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const stakingToken = await Token.deploy("ETH", "ETH", 18, 1000);
        const rewardsToken = await Token.deploy("RWD", "RWD", 18, 2e12);
        const oracle = await Oracle.deploy();
        await stakingToken.deployed();
        await rewardsToken.deployed();
        await oracle.deployed();

        const farm0 = await Farm.deploy(stakingToken.address, rewardsToken.address, SIX_HOURS_IN_SECONDS, oracle.address);
        const farm1 = await Farm.deploy(stakingToken.address, rewardsToken.address, SIX_HOURS_IN_SECONDS, oracle.address);
        const farm2 = await Farm.deploy(stakingToken.address, rewardsToken.address, SIX_HOURS_IN_SECONDS, oracle.address);
        const farm3 = await Farm.deploy(stakingToken.address, rewardsToken.address, SIX_HOURS_IN_SECONDS, oracle.address);
        await farm0.deployed();
        await farm1.deployed();
        await farm2.deployed();
        await farm3.deployed();

        const core = await Core.deploy();
        await core.deployed();

        await core.setActiveFarms(farm0.address, farm1.address, farm2.address, farm3.address);

        await stakingToken.transfer(owner.address, 1000);

        return { stakingToken, rewardsToken, core, owner, addr1, addr2, farm0, farm1, farm2, farm3 };
    }

    describe("Deployment", function () {
        it("Deploy correctly", async function () {
            const { core, owner } = await loadFixture(deployFixture);
            expect(await core.owner()).to.equal(owner.address);

            console.log("=>>", await core.farms(2));
        });

        it("Updates score", async function () {
            const { core, owner, stakingToken, rewardsToken, farm0, farm1, farm2, farm3 } = await loadFixture(deployFixture);

            // Deposit to farms so TVL can be updated...
            await stakingToken.approve(farm0.address, 150);
            await farm0.deposit(150);
            await stakingToken.approve(farm1.address, 200);
            await farm1.deposit(200);
            await stakingToken.approve(farm2.address, 150);
            await farm2.deposit(150);
            await stakingToken.approve(farm3.address, 200);
            await farm3.deposit(200);

            await core.update();

            console.log("tvl0", await farm0.totalValueLocked());
            console.log("tvl1", await farm1.totalValueLocked());
            console.log("tvl2", await farm2.totalValueLocked());
            console.log("tvl3", await farm3.totalValueLocked());

            expect(await core.score()).to.equal(86);

            await time.increase(SIX_HOURS_IN_SECONDS);

            await farm2.withdraw(50);

            await core.update();
            console.log("obs.len", await core.getObservationsLength());

            expect(await core.score()).to.equal(86);
        });
    });
});


