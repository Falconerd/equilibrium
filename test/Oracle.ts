import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Oracle contract", function () {
    async function deployTokenFixture() {
        const MockOracle = await ethers.getContractFactory("MockOracle");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const eqlToken = await Token.deploy();
        await eqlToken.deployed();

        return { Token, eqlToken, owner, addr1, addr2 };
    }
    describe("Deployment", function () {
        it("Should d", async function () {

        });
    });
});

