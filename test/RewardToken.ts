import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("RewardToken contract", function () {
    async function deployTokenFixture() {
        const RewardToken = await ethers.getContractFactory("RewardToken");
        const [owner] = await ethers.getSigners();

        const token = await RewardToken.deploy();
        await token.deployed();

        return { RewardToken, token, owner };
    }

    describe("Deployment", function () {
        it("Should assign all tokens to the deployer", async function () {
            const { token, owner } = await loadFixture(deployTokenFixture);
            expect(await token.totalSupply()).to.equal(100_000_000);
            expect(await token.balanceOf(owner.address)).to.equal(100_000_000);
        });
    });
});

