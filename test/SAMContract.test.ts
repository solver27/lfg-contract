const { assert } = require ("chai");

const {expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftEscrowArt = hre.artifacts.require("NftEscrow");
const SAMContractArt = hre.artifacts.require("SAMContract");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("SAMContract", function () {
  let LFGToken = null;
  let LFGNFT = null;
  let NftEscrow = null;
  let SAMContract = null;
  let accounts = ["", "", "", "", "", "", ""],
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6], minter] = await web3.eth.getAccounts();
      LFGToken = await LFGTokenArt.new("LFG Token",
      "LFG",
      "1000000000000000000000000000", minter);

      LFGNFT = await LFGNFTArt.new();
      NftEscrow = await NftEscrowArt.new(minter, LFGToken.address);

      SAMContract = await SAMContractArt.new(minter, NftEscrow.address);

      await LFGNFT.setMinter(minter, true);

      await NftEscrow.setOperator(SAMContract.address, {from: minter}); // During construct owner changed to minter

      const operatorResult = await NftEscrow.operator();
      console.log("get operator: ", operatorResult.toString());
  
    } catch (err) {
      console.log(err);
    }
  });

  it("test buy now feature", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(2, accounts[2], {from: minter});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(NftEscrow.address, 1, {from: accounts[2]});

    const operatorResult = await NftEscrow.operator();
    console.log("get operator: ", operatorResult.toString());

    await SAMContract.addListing(LFGNFT.address, account2TokenIds[0], "10000000", "20000000", 3600 * 24, {from:accounts[2]});

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    let listingId = listingResult[0][0];

    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(accounts[1], testDepositAmount);

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("account 1 balance ", balance.toString());

    await LFGToken.approve(NftEscrow.address, testDepositAmount, {from: accounts[1]});
    await SAMContract.buyNow(listingId, {from: accounts[1]});

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "2");

    let account2Tokens = await NftEscrow.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"], "20000000");

    let balanceOfAccount0 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount0.toString());

    const account1Tokens = await NftEscrow.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));

    await SAMContract.claimToken({from: accounts[2]});

    account2Tokens = await NftEscrow.addrTokens(accounts[2]);
    console.log("After claim, Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    balanceOfAccount0 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount0.toString());
  });

  it("test auction and bidding", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    //await LFGNFT.mint(2, accounts[2], {from: minter});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(NftEscrow.address, account2TokenIds[0], {from: accounts[2]});

    const operatorResult = await NftEscrow.operator();
    console.log("get operator: ", operatorResult.toString());

    await SAMContract.addListing(LFGNFT.address, account2TokenIds[0], "10000000", "20000000", 3600 * 24, {from:accounts[2]});

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    let listingId = listingResult[0][0];

    const testDepositAmount = "100000000000000000000000";
    for (let accountId = 3; accountId < 6; ++accountId) {
        await LFGToken.transfer(accounts[accountId], testDepositAmount);
        await LFGToken.approve(NftEscrow.address, testDepositAmount, {from: accounts[accountId]});
    }

    await expect(
        SAMContract.placeBid(listingId, "10000000", { from: accounts[3]})
      ).to.be.revertedWith("Bid price too low");

    await SAMContract.placeBid(listingId, "10000010", { from: accounts[3]});

    await expect(
        SAMContract.placeBid(listingId, "10000010", { from: accounts[4]})
      ).to.be.revertedWith("Bid price too low");

    await SAMContract.placeBid(listingId, "10000020", { from: accounts[4]});
    await SAMContract.placeBid(listingId, "10000050", { from: accounts[5]});

    const biddings = await SAMContract.biddingOfListing(listingId);
    console.log("All biddings: ", JSON.stringify(biddings));

    // let account3Index = 0;
    // for (let index = 0; index < 3; ++index) {
    //     if (biddings[index][1] == accounts[3]) {
    //         account3Index = index;
    //     }
    // }
    // console.log("account3 bidding index ", account3Index);

    await expect(
        SAMContract.claimNft(biddings[0][0], {from: accounts[3]})
        ).to.be.revertedWith("The bidding period haven't complete");

    const today = Math.round(new Date() / 1000);
    await hre.network.provider.send("evm_setNextBlockTimestamp", [today + 3601 * 24]);
    await hre.network.provider.send("evm_mine");

    await expect(
        SAMContract.claimNft(biddings[0][0], {from: accounts[3]})
        ).to.be.revertedWith("The bidding is not the highest price");

    await SAMContract.claimNft(biddings[2][0], {from: accounts[5]});
  });
});
