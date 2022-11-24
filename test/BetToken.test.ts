import { expect } from "chai";
import { ethers } from "hardhat";

describe("BetToken", function () {
  it("Mock test", async function () {
    const BetToken = await ethers.getContractFactory("BetToken");
    const betToken = await BetToken.deploy();
    await betToken.deployed();
  });
})