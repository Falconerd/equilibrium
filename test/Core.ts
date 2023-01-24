import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Core contract", function () {
    async function deployFixture() {
        const Core = await ethers.getContractFactory("Core");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const eqlCore = await Core.deploy();
        await eqlCore.deployed();

        return { Core, eqlCore, owner, addr1, addr2 };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { eqlCore, owner } = await loadFixture(deployFixture);

            expect(await eqlCore.owner()).to.equal(owner.address);
        });

        it("Should init the EQL token", async function () {
            const { eqlCore } = await loadFixture(deployFixture);

            expect(await eqlCore.eql_token()).to.equal("0xa16E02E87b7454126E5E10d957A927A7F5B5d2be");
        });

        it("Should have empty farm groups", async function () {
            const { eqlCore } = await loadFixture(deployFixture);

            expect(await eqlCore.active_farm_a()).not.to.equal(0);
            expect(await eqlCore.active_farm_b()).not.to.equal(0);
            expect(await eqlCore.active_farm_c()).not.to.equal(0);
        });
    });

    describe("Usage", function () {
        it("Should deploy a farm", async function () {
            const { eqlCore } = await loadFixture(deployFixture);
            await eqlCore.deploy("0xa16E02E87b7454126E5E10d957A927A7F5B5d2be", "0xa16E02E87b7454126E5E10d957A927A7F5B5d2be", "0xa16E02E87b7454126E5E10d957A927A7F5B5d2be");
            const farmByPair = await eqlCore.farm_by_pair("0xa16E02E87b7454126E5E10d957A927A7F5B5d2be");

            expect(await eqlCore.farms(0)).to.equal(farmByPair);
        });
    });
});

