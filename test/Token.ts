import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Token contract", function () {
    async function deployTokenFixture() {
        const Token = await ethers.getContractFactory("Token");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const token = await Token.deploy("Token", "TKN", 18, 100_000_000);
        await token.deployed();

        return { token, owner, addr1, addr2 };
    }

    describe("Deployment", function () {
        it("Should assign all tokens to the deployer", async function () {
            const { token, owner } = await loadFixture(deployTokenFixture);
            expect(await token.totalSupply()).to.equal(100_000_000);
            expect(await token.balanceOf(owner.address)).to.equal(100_000_000);
        });

        it("Should transfer tokens between accounts", async function () {
            const { token, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            await expect(token.transfer(addr1.address, 50)).to.changeTokenBalances(token, [owner, addr1], [-50, 50]);
            await expect(token.connect(addr1).transfer(addr2.address, 50)).to.changeTokenBalances(token, [addr1, addr2], [-50, 50]);
        });

        it("Should record the holders", async function () {
            const { token, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            expect(await token.inserted(owner.address)).to.equal(true);
            await expect(token.transfer(addr1.address, 50)).to.changeTokenBalances(token, [owner, addr1], [-50, 50]);

            expect(await token.inserted(addr2.address)).to.equal(false);

            await token.connect(addr1).transfer(addr2.address, 50);
            expect(await token.inserted(addr2.address)).to.equal(true);

        });

        it("Should fail if sender doesn't have enough tokens", async function () {
            const { token, owner, addr1 } = await loadFixture(deployTokenFixture);

            const initialOwnerBalance = await token.balanceOf(owner.address);

            await expect(token.connect(addr1).transfer(owner.address, 1)).to.be.reverted;
            expect(await token.balanceOf(owner.address)).to.equal(initialOwnerBalance);
        });

        it("Should not allow account to use transferFrom with no allowance", async function () {
            const { token, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            await expect(token.connect(addr2).transferFrom(owner.address, addr1.address, 1)).to.be.reverted;
        });

        it("Should not allow sender with no tokens to transferFrom", async function () {
            const { token, owner, addr1 } = await loadFixture(deployTokenFixture);

            await expect(token.transferFrom(addr1.address, owner.address, 1)).to.be.reverted;
        });

        it("Should allow another account to use transferFrom", async function () {
            const { token, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);

            await token.approve(addr2.address, 1000);
            await token.connect(addr2).approve(owner.address, 1000);
            await token.connect(addr2).transferFrom(owner.address, addr1.address, 100);

            expect(await token.balanceOf(addr1.address)).to.equal(100);
            expect(await token.balanceOf(owner.address)).to.equal(1e8 - 100);
            expect(await token.balanceOf(addr2.address)).to.equal(0);
        });
    });
});
