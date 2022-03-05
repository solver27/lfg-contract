const { assert, expect } = require("chai");
const hre = require("hardhat");
const { web3 } = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const BurnTokenArt = hre.artifacts.require("BurnToken");
const BN = require("bn.js");
const { createImportSpecifier } = require("typescript");

describe("BurnToken", function () {
  let LFGToken = null;
  let BurnToken = null;
  let owner, operator, burnAddress;

  before("Deploy contract", async function () {
    try {
      [owner, operator, burnAddress] = await web3.eth.getAccounts();
      LFGToken = await LFGTokenArt.new("LFG Token",
        "LFG",
        "1000000000000000000000000000", owner);

      BurnToken = await BurnTokenArt.new(owner, LFGToken.address, burnAddress);
    } catch (err) {
      console.log(err);
    }
  });

  it("test burn token feature", async function () {
    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(BurnToken.address, testDepositAmount);

    let totalBurnAmount = await BurnToken.totalBurnAmount();
    assert.equal(totalBurnAmount.toString(), "0");

    await expect(
      BurnToken.burn(10000, { from: operator })
    ).to.be.revertedWith("Invalid operator");

    await BurnToken.setOperator(operator, true, { from: owner} );

    await BurnToken.burn(10000, { from: operator });

    totalBurnAmount = await BurnToken.totalBurnAmount();
    assert.equal(totalBurnAmount.toString(), "500");

    let burnAddrBal = await LFGToken.balanceOf(burnAddress);
    assert.equal(burnAddrBal.toString(), "500");

    // Set burn rate to 10%
    await BurnToken.setBurnRate(1000);

    await BurnToken.burn(10000, { from: operator });

    totalBurnAmount = await BurnToken.totalBurnAmount();
    assert.equal(totalBurnAmount.toString(), "1500");

    burnAddrBal = await LFGToken.balanceOf(burnAddress);
    assert.equal(burnAddrBal.toString(), "1500");
  });
});
