import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Vault contract", function () {
    async function vaultTokenFixture() {
        const RewardToken = await ethers.getContractFactory("RewardToken");
        const VaultToken = await ethers.getContractFactory("Vault");
        const [owner] = await ethers.getSigners();

        const rewardToken = await RewardToken.deploy();
        await rewardToken.deployed();
        const token = await VaultToken.deploy(rewardToken.address);
        await token.deployed();

        return { token, rewardToken, owner };
    }

    describe("Deployment", function () {
        it("Should start with 0 tokens minted", async function () {
            const { token } = await loadFixture(vaultTokenFixture);
            expect(await token.totalSupply()).to.equal(0);
        });
    });

    describe("Usage", function () {
        it("Should accept RewardToken as a deposit", async function () {
            const { owner, token, rewardToken } = await loadFixture(vaultTokenFixture);

            const initialRewardTokenBalance = await rewardToken.balanceOf(owner.address);

            await rewardToken.approve(token.address, 100);
            await token.deposit(100);

            expect(await rewardToken.balanceOf(owner.address)).to.equal(initialRewardTokenBalance.sub(100));
            expect(await rewardToken.balanceOf(token.address)).to.equal(100);
            expect(await token.balanceOf(owner.address)).to.equal(100);
            expect(await token.totalSupply()).to.equal(100);
        });

        it("Should allow withdrawal of RewardToken", async function() {
            const { owner, token, rewardToken } = await loadFixture(vaultTokenFixture);

            await rewardToken.approve(token.address, 100);
            await token.deposit(100);

            const initialRewardTokenBalance = await rewardToken.balanceOf(owner.address);

            await token.withdraw(50);

            expect(await rewardToken.balanceOf(owner.address)).to.equal(initialRewardTokenBalance.add(50));
            expect(await token.balanceOf(owner.address)).to.equal(50);
        });
    });
});


