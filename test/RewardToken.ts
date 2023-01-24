import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("RewardToken contract", function () {
    async function deployTokenFixture() {
        const RewardToken = await ethers.getContractFactory("RewardToken");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const token = await RewardToken.deploy();
        await token.deployed();

        return { RewardToken, token, owner, addr1, addr2 };
    }
});

