const { assert, expect } = require("chai");
const hre = require("hardhat");
const { web3 } = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGNFT1155Art = hre.artifacts.require("LFGNFT1155");
const NftWhiteListArt = hre.artifacts.require("NftWhiteList");
const SAMContractGasArt = hre.artifacts.require("SAMContractGas");
const BN = require("bn.js");
const { createImportSpecifier } = require("typescript");

async function getBiddingOfAddr(samContract, addr) {
  const biddingIds = await samContract.biddingOfAddr(addr);
  let results = new Array();
  for (let index in biddingIds) {
    const biddingId = biddingIds[index];
    const biddingInfo = await samContract.biddingRegistry(biddingId);
    results.push(biddingInfo);
  }
  console.log("getBiddingOfAddr result: ", JSON.stringify(results));
  return results;
}

describe("SAMContractGas1155", function () {
  let LFGToken = null;
  let LFGNFT1155 = null;
  let NftWhiteList = null;
  let SAMContractGas = null;
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

      SAMContractGas = await SAMContractGasArt.new(
        minter,
        NftWhiteList.address
      );

      // This one must call from owner
      await NftWhiteList.setNftContractWhitelist(LFGNFT1155.address, true, {
        from: minter,
      });

      // 2.5% fee, 10% royalties fee.
      await SAMContractGas.updateFeeRate(250, 1000, { from: minter });

    } catch (err) {
      console.log(err);
    }
  });

  it("test buy now feature", async function () {
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

    await LFGNFT1155.setApprovalForAll(SAMContractGas.address, true, {
      from: accounts[2],
    });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContractGas.addListing(
      LFGNFT1155.address,
      id,
      0,
      "2000000000000000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      { from: accounts[2] }
    );

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await expect(
      SAMContractGas.placeBid(listingId, {
        from: accounts[1],
        value: "1000000000000000000",
      })
    ).to.be.revertedWith("Can only bid for listing on auction");

    await SAMContractGas.buyNow(listingId, {
      from: accounts[1],
      value: hre.ethers.utils.parseEther("2.05"),
    }); // 20500000

    await hre.network.provider.send("evm_mine");

    let nftBalanceOfAccount1  = await LFGNFT1155.balanceOf(accounts[1], id);
    console.log("balance of of account 1 ", JSON.stringify(nftBalanceOfAccount1));
    assert.equal(nftBalanceOfAccount1, "1");

    nftBalanceOfAccount2 = await LFGNFT1155.balanceOf(accounts[2], id);
    console.log("NFT Balance of account 2 ", nftBalanceOfAccount2.toString());
    assert.equal(nftBalanceOfAccount2.toString(), "1");

    let balanceOfAccount1 = await web3.eth.getBalance(accounts[1]);
    console.log("Balance of account 1 ", balanceOfAccount1.toString());
    assert.isBelow(
      parseInt(balanceOfAccount1.toString()),
      9998000000000000000000
    );

    let balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    let account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(
      account2Tokens["claimableAmount"].toString(),
      "2000000000000000000"
    );

    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    await SAMContractGas.claimBalance({ from: accounts[2] });
    balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.isAbove(
      parseInt(balanceOfAccount2.toString()),
      10001999057036928800000
    );

    account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"].toString(), "0");

    let revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "50000000000000000");
  });
});