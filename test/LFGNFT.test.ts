const {expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("LFGNFT", function () {
  let LFGNFT = null;
  let NftAirdrop = null;
  let accounts = ["", ""],
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], minter] = await web3.eth.getAccounts();
      LFGNFT = await LFGNFTArt.new();
      await LFGNFT.setMinter(minter, true);
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT Royalties", async function () {
    let minterResult = await LFGNFT.minters(minter);
    console.log("Get minter result ", minterResult.toString());

    await LFGNFT.mint(1, accounts[1], {from: minter} );
    const nftBalance = await LFGNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account1 ", JSON.stringify(account1TokenIds));

    let royaltyInfo = await LFGNFT.royaltyInfo(account1TokenIds[0], 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    // Before set royalty, it should be 0
    assert.equal(royaltyInfo["royaltyAmount"], "0");

    // set 10% royalty
    await LFGNFT.setRoyalty(account1TokenIds[0], accounts[1], 1000, {from: minter});
  
    royaltyInfo = await LFGNFT.royaltyInfo(account1TokenIds[0], 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    assert.equal(royaltyInfo["receiver"], accounts[1]);
    assert.equal(royaltyInfo["royaltyAmount"], "1000");
  });
});
