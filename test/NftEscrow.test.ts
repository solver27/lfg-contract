const {expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftEscrowArt = hre.artifacts.require("NftEscrow");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("NftEscrow", function () {
  let LFGNFT = null;
  let NftEscrow = null;
  let accounts = ["", ""],
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], minter] = await web3.eth.getAccounts();
      LFGNFT = await LFGNFTArt.new();
      NftEscrow = await NftEscrowArt.new(minter);

      await LFGNFT.setMinter(minter, true);
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT Escrow", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(2, accounts[0], {from: minter});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let tokenIds = await LFGNFT.tokensOfOwner(accounts[0]);
    console.log("tokenIds ", JSON.stringify(tokenIds));

    await LFGNFT.approve(NftEscrow.address, 1);

    await NftEscrow.depositNft(LFGNFT.address, 1, {from: accounts[0]});
    tokenIds = await LFGNFT.tokensOfOwner(accounts[0]);
    console.log("tokenIds ", JSON.stringify(tokenIds));

    await NftEscrow.withdrawNft(LFGNFT.address, 1, {from: accounts[0]});
    tokenIds = await LFGNFT.tokensOfOwner(accounts[0]);
    console.log("tokenIds ", JSON.stringify(tokenIds));
  });
});
