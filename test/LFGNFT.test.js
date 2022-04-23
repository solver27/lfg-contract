const { assert, expect } = require("chai");
const hre = require("hardhat");
const { web3 } = require("hardhat");
const LFGNFTArt = hre.artifacts.require("LFGNFT");

describe("LFGNFT", function () {
  let LFGNFT = null;
  let accounts = ["", ""],
    owner,
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], owner, minter] = await web3.eth.getAccounts();
      LFGNFT = await LFGNFTArt.new(owner);
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT Royalties", async function () {
    await LFGNFT.mint(1, accounts[1], { from: accounts[1] });
    const nftBalance = await LFGNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account1 ", JSON.stringify(account1TokenIds));

    let royaltyInfo = await LFGNFT.royaltyInfo(account1TokenIds[0], 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    // Before set royalty, it should be 0
    assert.equal(royaltyInfo["royaltyAmount"], "0");

    // set 10% royalty
    await LFGNFT.setRoyalty(account1TokenIds[0], accounts[1], 1000, {
      from: accounts[1],
    });

    await expect(
      LFGNFT.setRoyalty(account1TokenIds[0], accounts[1], 2100, {
        from: accounts[1],
      })
    ).to.be.revertedWith("NFT: Invalid royalty percentage");

    royaltyInfo = await LFGNFT.royaltyInfo(account1TokenIds[0], 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    assert.equal(royaltyInfo["receiver"], accounts[1]);
    assert.equal(royaltyInfo["royaltyAmount"], "1000");
  });

  it("test max batch quantity", async function () {
    await expect(
      LFGNFT.mint(11, accounts[1], { from: minter })
    ).to.be.revertedWith("NFT: cannot mint over max batch quantity");

    await LFGNFT.setMaxBatchQuantity(20, { from: owner });

    let getMaxBatchQuantity = await LFGNFT.maxBatchQuantity();
    assert.equal(getMaxBatchQuantity.toString(), "20");

    await LFGNFT.mint(11, accounts[1], { from: minter });
  });
});
