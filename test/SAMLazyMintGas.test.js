const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const UserBlackListArt = hre.artifacts.require("UserBlackList");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const LFGNFT1155Art = hre.artifacts.require("LFGNFT1155");
const SAMConfigArt = hre.artifacts.require("SAMConfig");
const SAMLazyMintGasArt = hre.artifacts.require("SAMLazyMintGas");
const BurnTokenArt = hre.artifacts.require("BurnToken");

describe("SAMLazyMintGas", function () {
  let LFGToken = null;
  let UserBlackList = null;
  let LFGNFT = null;
  let LFGNFT1155 = null;
  let SAMLazyMintGas = null;
  let accounts = ["", "", "", "", "", "", ""],
    owner,
    burnAddress,
    revenueAddress,
    burnAddress1;

  before("Deploy contract", async function () {
    try {
      [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
        accounts[5],
        accounts[6],
        owner,
        burnAddress,
        revenueAddress,
        burnAddress1,
      ] = await web3.eth.getAccounts();

      UserBlackList = await UserBlackListArt.new(owner);

      LFGNFT1155 = await LFGNFT1155Art.new(owner, UserBlackList.address, "");

      SAMConfig = await SAMConfigArt.new(owner, revenueAddress, burnAddress);

      SAMLazyMintGas = await SAMLazyMintGasArt.new(owner, LFGNFT1155.address, SAMConfig.address);

      // 2.5% fee, 50% of the fee burn, 10% royalties fee.
      await SAMLazyMintGas.updateFeeRate(250, {from: owner});
      await SAMConfig.setRoyaltiesFeeRate(1000, {from: owner});
    } catch (err) {
      console.log(err);
    }
  });

  it("test buy now feature", async function () {
    let firstCreateor = await LFGNFT1155.creators(1);
    console.log("firstCreateor ", firstCreateor.toString());
    assert.equal(firstCreateor, "0x0000000000000000000000000000000000000000");

    const collectionTag = web3.utils.asciiToHex("CryoptKitty");
    await LFGNFT1155.createCollection(collectionTag, {
      from: accounts[2],
    });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMLazyMintGas.addCollectionListing(
      collectionTag,
      10, // Collection count 10
      0,
      "2000000000000000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMLazyMintGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 10);
    let listingId = listingResult[0];

    await expect(SAMLazyMintGas.placeBid(listingId, "10000000", {from: accounts[1]})).to.be.revertedWith(
      "Can only bid for listing on auction"
    );

    await expect(SAMLazyMintGas.buyNow(listingId, {from: accounts[2]})).to.be.revertedWith("Buyer cannot be seller");

    await SAMLazyMintGas.buyNow(listingId, {from: accounts[1], value: hre.ethers.utils.parseEther("2.05")});

    firstCreateor = await LFGNFT1155.creators(1);
    console.log("firstCreateor ", firstCreateor.toString());
    assert.equal(firstCreateor, SAMLazyMintGas.address);

    let tokenSupply = await LFGNFT1155.tokenSupply(1);
    assert.equal(tokenSupply.toString(), "1");

    let buyerBalance = await LFGNFT1155.balanceOf(accounts[1], 1);
    assert.equal(buyerBalance.toString(), "1");

    let balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    listingResult = await SAMLazyMintGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 9);

    balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.isAbove(parseInt(balanceOfAccount2.toString()), 10001992111885711000000);
  });
});
