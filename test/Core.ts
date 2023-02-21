import { expect } from "chai";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Core contract", function () {
    async function deployFixture() {
        const Core = await ethers.getContractFactory("Core");
        const [owner] = await ethers.getSigners();

        const core = await Core.deploy();
        await core.deployed();

        return { core, owner };
    }

    describe("Deployment", function () {
        it("Deploy correctly", async function () {
            const { core, owner } = await loadFixture(deployFixture);
            expect(await core.owner()).to.equal(owner.address);
        });

        it("Updates score", async function () {
            const { core, owner } = await loadFixture(deployFixture);
            await core.update();

            expect(await core.score()).to.equal(100);
        });
    });
});


