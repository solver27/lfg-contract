const {expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftAirdropArt = hre.artifacts.require("NftAirdrop");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("NftAirdrop", function () {
  let LFGNFT = null;
  let NftAirdrop = null;
  let accounts = ["", ""],
    minter;

  const airDropNftAmount = 2;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], minter] = await web3.eth.getAccounts();
      LFGNFT = await LFGNFTArt.new();
      NftAirdrop = await NftAirdropArt.new(LFGNFT.address);
      await LFGNFT.setMinter(NftAirdrop.address, true);
    } catch (err) {
      console.log(err);
    }
  });

  it("test claim NFT method", async function () {
    const today = Math.round(new Date() / 1000);
    await hre.network.provider.send("evm_setNextBlockTimestamp", [today + 1000]);
    await hre.network.provider.send("evm_mine");
    await NftAirdrop.addWhitelists([accounts[1]], [airDropNftAmount]);

    let minterResult = await LFGNFT.minters(NftAirdrop.address);
    console.log("Get minter result ", minterResult.toString());

    const whitelistInfo = await NftAirdrop.whitelistPools(accounts[1]);
    expect(new BN(whitelistInfo.nftAmount).toString()).to.equal(airDropNftAmount.toString());
    expect(new BN(whitelistInfo.distributedAmount).toString()).to.equal("0");

    await NftAirdrop.claimDistribution({from: accounts[1]});
    expect(new BN(whitelistInfo.nftAmount).toString()).to.equal(airDropNftAmount.toString());
    expect(new BN(whitelistInfo.distributedAmount).toString()).to.equal(airDropNftAmount.toString());
  });
});
