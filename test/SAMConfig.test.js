const {BigNumber} = require("bignumber.js");
const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const SAMConfigArt = hre.artifacts.require("SAMConfig");

describe("SAMConfig", function () {
  let SAMConfig = null;
  let accounts = ["", "", "", "", "", "", ""],
  owner,
  burnAddress,
  revenueAddress,
  burnAddress1;

  before("Deploy contract", async function () {
    try {
      [
        owner,
        burnAddress,
        revenueAddress,
      ] = await web3.eth.getAccounts();
      SAMConfig = await SAMConfigArt.new(owner, revenueAddress, burnAddress);
    } catch (err) {
      console.log(err);
    }
  });

  it("test set valid fee rate", async function() {
    await SAMConfig.setRoyaltiesFeeRate(1000, {from: owner});
    const royaltyFeeRate = await SAMConfig.getRoyalityFeeRate();
    console.log('RoyaltiesFeeRate ', royaltyFeeRate);
    await expect(SAMConfig.setRoyaltiesFeeRate(5001, {from: owner})).to.be.revertedWith("Invalid royalities fee rate");

    await SAMConfig.setFeeBurnRate(5000, {from: owner});
    const feeBurnRate = await SAMConfig.getFeeBurnRate();
    console.log('FeeBurnRate ', feeBurnRate);
    await expect(SAMConfig.setFeeBurnRate(10001, {from: owner})).to.be.revertedWith("Invalid fee burn rate");
  });

  it("test set valid revenue address", async function() {
    await SAMConfig.setRevenueAddress(revenueAddress, {from: owner});
    const revenueAddr = await SAMConfig.getRevenueAddress();
    console.log('RevenueAddress ', revenueAddr);
    await expect(SAMConfig.setRevenueAddress("0x0000000000000000000000000000000000000000", {from: owner})).to.be.revertedWith("Invalid revenue address");
  });

  it("test set valid duration", async function() {
    await SAMConfig.setMinDuration(24 * 3600, {from: owner});
    const minDuration = await SAMConfig.getMinDuration()
    console.log('MinDuration ', minDuration);
    await expect(SAMConfig.setMinDuration(8 * 24 * 3600, {from: owner})).to.be.revertedWith("Invalid minimum duration");

    await SAMConfig.setMaxDuration(8 * 24 * 3600, {from: owner});
    const maxDuration = await SAMConfig.getMaxDuration();
    console.log('MaxDuration ', maxDuration);
    await expect(SAMConfig.setMaxDuration( 0.5 * 24 * 3600, {from: owner})).to.be.revertedWith("Invalid maximum duration");
  });

});  