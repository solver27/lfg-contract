const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGFireNFTArt = hre.artifacts.require("LFGFireNFT");

describe("LFGFireNFT", function () {
  let LFGFireNFT = null;
  let accounts = ["", "", "", ""],
    owner,
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], accounts[3], owner, minter] = await web3.eth.getAccounts();
      LFGFireNFT = await LFGFireNFTArt.new(owner);
      await LFGFireNFT.setMinter(minter, true, {from: owner});
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT Royalties", async function () {
    await LFGFireNFT.mint(1, accounts[1], {from: minter});
    let nftBalance = await LFGFireNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());
    assert.equal(nftBalance.toString(), "1");

    let account1TokenIds = await LFGFireNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    await LFGFireNFT.multiMint([accounts[1], accounts[2], accounts[3]], {from: owner});

    let account3TokenIds = await LFGFireNFT.tokensOfOwner(accounts[3]);
    console.log("tokenIds of account3 ", JSON.stringify(account3TokenIds));
    assert.equal(account3TokenIds[0], "4");

    nftBalance = await LFGFireNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());
    // Single minted to account 1 once, multiple mint to it once, so total is 2
    assert.equal(nftBalance.toString(), "2");

    const totalSupply = await LFGFireNFT.totalSupply();
    assert.equal(totalSupply.toString(), "4");
  });
});
