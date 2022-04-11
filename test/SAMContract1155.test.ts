const { assert, expect } = require("chai");
const hre = require("hardhat");
const { web3 } = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGNFT1155Art = hre.artifacts.require("LFGNFT1155");
const NftWhiteListArt = hre.artifacts.require("NftWhiteList");
const SAMContractArt = hre.artifacts.require("SAMContract");
const BurnTokenArt = hre.artifacts.require("BurnToken");
const BN = require("bn.js");
const { createImportSpecifier } = require("typescript");

describe("SAMContract1155", function () {
  let LFGToken = null;
  let LFGNFT1155 = null;
  let NftWhiteList = null;
  let SAMContract = null;
  let BurnToken = null;
  let accounts = ["", "", "", "", "", "", ""],
    minter,
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
        minter,
        burnAddress,
        revenueAddress,
        burnAddress1,
      ] = await web3.eth.getAccounts();
      LFGToken = await LFGTokenArt.new(
        "LFG Token",
        "LFG",
        "1000000000000000000000000000",
        minter
      );

      LFGNFT1155 = await LFGNFT1155Art.new(minter, "");

      NftWhiteList = await NftWhiteListArt.new(minter);

      SAMContract = await SAMContractArt.new(
        minter,
        LFGToken.address,
        NftWhiteList.address,
        burnAddress,
        revenueAddress
      );

      // This one must call from owner
      await NftWhiteList.setNftContractWhitelist(LFGNFT1155.address, true, {
        from: minter,
      });

      // 2.5% fee, 50% of the fee burn, 10% royalties fee.
      await SAMContract.updateFeeRate(250, 1000, { from: minter });
      await SAMContract.updateBurnFeeRate(5000, { from: minter });

      BurnToken = await BurnTokenArt.new(
        minter,
        LFGToken.address,
        burnAddress1
      );
      await BurnToken.setOperator(SAMContract.address, true, { from: minter });
    } catch (err) {
      console.log(err);
    }
  });

  it("test 1155 NFT buy now feature", async function () {
    let result = await LFGNFT1155.create(accounts[2], 2, "0x0", {
      from: accounts[2],
    });
    result = await LFGNFT1155.create(accounts[2], 2, "0x0", {
      from: accounts[2],
    });
    let id = result["logs"][0]["args"]["id"];
    console.log("id: ", id.toString());

    let nftBalanceOfAccount2 = await LFGNFT1155.balanceOf(accounts[2], id);
    console.log("NFT Balance of account 2 ", nftBalanceOfAccount2.toString());

    let supply = await LFGNFT1155.tokenSupply(id);
    console.log("supply ", supply.toString());

    await LFGNFT1155.setApprovalForAll(SAMContract.address, true, {
      from: accounts[2],
    });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContract.addListing(
      LFGNFT1155.address,
      id,
      0,
      "20000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      { from: accounts[2] }
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);

    let balanceOfMarketplace = await LFGNFT1155.balanceOf(
      SAMContract.address,
      id
    );
    console.log(
      "balance of of market place ",
      JSON.stringify(balanceOfMarketplace)
    );
    assert.equal(balanceOfMarketplace.toString(), "1");

    let listingId = listingResult[0];

    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(accounts[1], testDepositAmount, { from: minter });

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("account 1 balance ", balance.toString());

    await LFGToken.approve(SAMContract.address, testDepositAmount, {
      from: accounts[1],
    });

    await expect(
      SAMContract.placeBid(listingId, "10000000", { from: accounts[1] })
    ).to.be.revertedWith("Can only bid for listing on auction");

    await expect(
      SAMContract.buyNow(listingId, { from: accounts[2] })
    ).to.be.revertedWith("Buyer cannot be seller");

    await SAMContract.buyNow(listingId, { from: accounts[1] });

    let nftBalanceOfAccount1 = await LFGNFT1155.balanceOf(accounts[1], id);
    console.log(
      "balance of of account 1 ",
      JSON.stringify(nftBalanceOfAccount1)
    );
    assert.equal(nftBalanceOfAccount1, "1");

    nftBalanceOfAccount2 = await LFGNFT1155.balanceOf(accounts[2], id);
    console.log("NFT Balance of account 2 ", nftBalanceOfAccount2.toString());
    assert.equal(nftBalanceOfAccount2.toString(), "1");

    const account1Tokens = await SAMContract.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));

    let lfgBalanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Token Balance of account 2 ", lfgBalanceOfAccount2.toString());
    assert.equal(lfgBalanceOfAccount2.toString(), "20000000");

    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    let burnAmount = await LFGToken.balanceOf(burnAddress);
    console.log("Burn amount ", burnAmount.toString());
    assert.equal(burnAmount.toString(), "250000");
  });
});
