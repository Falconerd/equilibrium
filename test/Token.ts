import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Token contract", function () {
    async function deployTokenFixture() {
        const Token = await ethers.getContractFactory("Token");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const eqlToken = await Token.deploy();
        await eqlToken.deployed();

        return { Token, eqlToken, owner, addr1, addr2 };
    }

    describe("Deployment", function () {
        it("Should assign the total supply of tokens to the owner", async function () {
            const { eqlToken, owner } = await loadFixture(deployTokenFixture);
            const ownerBalance = await eqlToken.balanceOf(owner.address);

            expect(await eqlToken.totalSupply()).to.equal(ownerBalance);
        });

        it("Should transfer tokens between accounts", async function () {
            const { eqlToken, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            await expect(eqlToken.transfer(addr1.address, 50)).to.changeTokenBalances(eqlToken, [owner, addr1], [-50, 50]);
            await expect(eqlToken.connect(addr1).transfer(addr2.address, 50)).to.changeTokenBalances(eqlToken, [addr1, addr2], [-50, 50]);
        });

        it("Should emit Transfer events", async function () {
            const { eqlToken, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            await expect(eqlToken.transfer(addr1.address, 50)).to.emit(eqlToken, "Transfer").withArgs(owner.address, addr1.address, 50);
            await expect(eqlToken.connect(addr1).transfer(addr2.address, 50)).to.emit(eqlToken, "Transfer").withArgs(addr1.address, addr2.address, 50);
        });

        it("Should fail if sender doesn't have enough tokens", async function () {
            const { eqlToken, owner, addr1 } = await loadFixture(deployTokenFixture);
            const initialOwnerBalance = await eqlToken.balanceOf(owner.address);

            await expect(eqlToken.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith("EquilibriumV1: Not enough tokens.");

            expect(await eqlToken.balanceOf(owner.address)).to.equal(initialOwnerBalance);
        });
    });
});

