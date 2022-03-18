const { assert, expect } = require("chai");
const hre = require("hardhat");
const { web3 } = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGFireNFTArt = hre.artifacts.require("LFGFireNFT");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftWhiteListArt = hre.artifacts.require("NftWhiteList");
const SAMContractGasArt = hre.artifacts.require("SAMContractGas");
const BurnTokenArt = hre.artifacts.require("BurnToken");
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

describe("SAMContractGas", function () {
  let LFGToken = null;
  let LFGNFT = null;
  let LFGFireNFT = null;
  let NftWhiteList = null;
  let SAMContractGas = null;
  let BurnToken = null;
  let accounts = ["", "", "", "", "", "", ""],
    minter, burnAddress, revenueAddress, burnAddress1;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6],
        minter, burnAddress, revenueAddress, burnAddress1]
        = await web3.eth.getAccounts();
      LFGToken = await LFGTokenArt.new("LFG Token",
        "LFG",
        "1000000000000000000000000000", minter);

      LFGNFT = await LFGNFTArt.new();

      LFGFireNFT = await LFGFireNFTArt.new();

      NftWhiteList = await NftWhiteListArt.new(minter);

      SAMContractGas = await SAMContractGasArt.new(minter, NftWhiteList.address);

      // This one must call from owner
      await NftWhiteList.setNftContractWhitelist(LFGNFT.address, true, { from: minter });
      await NftWhiteList.setNftContractWhitelist(LFGFireNFT.address, true, { from: minter });

      // 2.5% fee, 10% royalties fee.
      await SAMContractGas.updateFeeRate(250, 1000, { from: minter });

      BurnToken = await BurnTokenArt.new(minter, LFGToken.address, burnAddress1);
      await BurnToken.setOperator(SAMContractGas.address, true, { from: minter });

    } catch (err) {
      console.log(err);
    }
  });

  it("test buy now feature", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    let acc1Balance = await web3.eth.getBalance(accounts[2]);
    console.log("Initial balance of account 1 ", acc1Balance.toString());

    await LFGNFT.mint(2, accounts[2], { from: minter });

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContractGas.address, 1, { from: accounts[2] });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContractGas.addListing(LFGNFT.address, account2TokenIds[0], 0, "2000000000000000000", latestBlock["timestamp"] + 1, 3600 * 24,
      0, 0, { from: accounts[2] });

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await expect(
      SAMContractGas.placeBid(listingId, { from: accounts[1], value: "1000000000000000000" })
    ).to.be.revertedWith("Can only bid for listing on auction");

    await SAMContractGas.buyNow(listingId, { from: accounts[1], value: hre.ethers.utils.parseEther("2.05") }); // 20500000

    await hre.network.provider.send("evm_mine");

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    let balanceOfAccount1 = await web3.eth.getBalance(accounts[1]);
    console.log("Balance of account 1 ", balanceOfAccount1.toString());
    assert.isBelow(parseInt(balanceOfAccount1.toString()), 9998000000000000000000);

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "2");

    let balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    let account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"].toString(), "2000000000000000000");

    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    await SAMContractGas.claimBalance({ from: accounts[2] });
    balanceOfAccount2 = await web3.eth.getBalance(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.isAbove(parseInt(balanceOfAccount2.toString()), 10001999357036928800000);

    account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"].toString(), "0");

    let revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "50000000000000000");
  });

  it("test auction and bidding", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContractGas.address, account2TokenIds[0], { from: accounts[2] });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContractGas.addListing(LFGNFT.address, account2TokenIds[0], 1, "1000000000000000000", latestBlock["timestamp"] + 1, 3600 * 24,
      0, 0, { from: accounts[2] });

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);

    let listingId = listingResult[0];

    await expect(
      SAMContractGas.placeBid(listingId, { from: accounts[3], value: "1000000000000000000" })
    ).to.be.revertedWith("Bid price too low");

    await SAMContractGas.placeBid(listingId, { from: accounts[3], value: "1100000000000000000" });
    await SAMContractGas.placeBid(listingId, { from: accounts[3], value: "1150000000000000000" });

    await expect(
      SAMContractGas.placeBid(listingId, { from: accounts[4], value: "1100000000000000000" })
    ).to.be.revertedWith("Bid price too low");

    await SAMContractGas.placeBid(listingId, { from: accounts[4], value: "1200000000000000000" });
    await SAMContractGas.placeBid(listingId, { from: accounts[5], value: "1500000000000000000" });

    //const biddings = await getBiddingOfAddr(SAMContractGas, accounts[3]);
    const biddingIds = await SAMContractGas.biddingOfAddr(accounts[3]);

    console.log("Biddings of address: ", JSON.stringify(biddingIds));

    const biddingDetails = await getBiddingOfAddr(SAMContractGas, accounts[3]);

    await expect(
      SAMContractGas.claimNft(biddingDetails[0][0], { from: accounts[3] })
    ).to.be.revertedWith("The bidding period haven't complete");

    const today = Math.round(new Date() / 1000);
    await hre.network.provider.send("evm_setNextBlockTimestamp", [today + 3601 * 24]);
    await hre.network.provider.send("evm_mine");

    await expect(
      SAMContractGas.claimNft(biddingDetails[0][0], { from: accounts[3] })
    ).to.be.revertedWith("The bidding is not the highest price");

    const biddingsOfAddr5 = await getBiddingOfAddr(SAMContractGas, accounts[5]);

    await SAMContractGas.claimNft(biddingsOfAddr5[0][0], { from: accounts[5], value: "37500000000000000" });
    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    let account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow tokens of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"].toString(), "1500000000000000000");

    // Account 3 bid failed, should be auto refunded
    let account3Tokens = await SAMContractGas.addrTokens(accounts[3]);
    console.log("Escrow tokens of account 3 ", JSON.stringify(account3Tokens));
    assert.equal(account3Tokens["claimableAmount"].toString(), "2250000000000000000");

    let revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "87500000000000000");

    await SAMContractGas.claimBalance({ from: accounts[2] });
  });

  it("test remove listing ", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(2, accounts[2], { from: minter });

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContractGas.address, account2TokenIds[0], { from: accounts[2] });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContractGas.addListing(LFGNFT.address, account2TokenIds[0], 1, "10000000", latestBlock["timestamp"] + 1, 3600 * 24,
      0, 0, { from: accounts[2] });

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await expect(
      SAMContractGas.removeListing(listingId, { from: accounts[2] })
    ).to.be.revertedWith("The listing haven't expired");

    const today = Math.round(new Date() / 1000);
    await hre.network.provider.send("evm_setNextBlockTimestamp", [today + 3601 * 48]);
    await hre.network.provider.send("evm_mine");

    await expect(
      SAMContractGas.removeListing(listingId, { from: accounts[1] })
    ).to.be.revertedWith("Only seller can remove");

    await SAMContractGas.removeListing(listingId, { from: accounts[2] });
    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 0);
  });

  it("test dutch auction ", async function () {
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContractGas.address, account2TokenIds[0], { from: accounts[2] });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContractGas.addListing(LFGNFT.address, account2TokenIds[0], 2, "1000000000000000000", latestBlock["timestamp"] + 1, 3600 * 24,
      3600, 100000, { from: accounts[2] });

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await expect(
      SAMContractGas.removeListing(listingId, { from: accounts[2] })
    ).to.be.revertedWith("The listing haven't expired");

    latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 3600 * 12]);
    await hre.network.provider.send("evm_mine");

    let currentPrice = await SAMContractGas.getPrice(listingId);
    console.log("currentPrice ", currentPrice.toString());

    await SAMContractGas.buyNow(listingId, { from: accounts[1], value: "1024999999998770000" });

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[1], "4");

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    const account1Tokens = await SAMContractGas.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));

    const account2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Balance of account 2 ", JSON.stringify(account2Tokens));
    assert.equal(account2Tokens["claimableAmount"], "999999999998800000");

    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    // Increased renuve 8800000 * 2.5% * 50% = 110000
    let revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "112499999999970000");

    await SAMContractGas.claimBalance({ from: accounts[2] });
  });

  it("test royalties payment after sell", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(1, accounts[2], { from: minter });

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    const lastIndex = account2TokenIds.length - 1;

    // 20% Royalties
    await LFGNFT.setRoyalty(account2TokenIds[lastIndex], accounts[6], 2000, { from: minter });

    await LFGNFT.approve(SAMContractGas.address, account2TokenIds[lastIndex], { from: accounts[2] });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContractGas.addListing(LFGNFT.address, account2TokenIds[lastIndex], 0, "2000000000000000000", latestBlock["timestamp"] + 1, 3600 * 24,
      0, 0, { from: accounts[2] });

    let listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await SAMContractGas.buyNow(listingId, { from: accounts[1], value: "2050000000000000000" });

    let account1Tokens = await SAMContractGas.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));
    assert.equal(account1Tokens["lockedAmount"], "0");

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "3");

    let acc2Tokens = await SAMContractGas.addrTokens(accounts[2]);
    console.log("Escrow amount of account 2 ", JSON.stringify(acc2Tokens));
    assert.equal(acc2Tokens["claimableAmount"], "1600000000000000000"); // 2000000000000000000 * 0.8, because 0.2 of the total pay royalties.

    listingResult = await SAMContractGas.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    let account6Tokens = await SAMContractGas.addrTokens(accounts[6]);
    console.log("Escrow amount of account 6 ", JSON.stringify(account6Tokens));
    assert.equal(account6Tokens["claimableAmount"], "360000000000000000"); // Because charged 10% royalties fee, so 4000000 becomes 3600000

    // Incresed revenue = 20000000 * 2.5% * 50% + 20000000 * 20% * 10% = 650000
    // Last step revenue is 547500, so total revenue is 547500 + 650000 = 1197500
    let revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "202499999999970000");

    await expect(
      SAMContractGas.revenueSweep()).to.be.revertedWith("Ownable: caller is not the owner");
    await SAMContractGas.revenueSweep({ from: minter });

    revenueAmount = await SAMContractGas.revenueAmount();
    assert.equal(revenueAmount.toString(), "0");

    let ownerBalance = await web3.eth.getBalance(minter);
    console.log("Owner balance after revenue sweep ", ownerBalance.toString());
    assert.isAbove(parseInt(ownerBalance.toString()), 10000201265050000000000);
  });

  it("Test fire NFT cannot sell for gas", async function () {
    // Top up burn contract
    await SAMContractGas.setFireNftContract(LFGFireNFT.address, { from: minter });

    let supply = await LFGFireNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGFireNFT.adminMint(2, accounts[2], { from: accounts[0] });

    supply = await LFGFireNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGFireNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGFireNFT.approve(SAMContractGas.address, 1, { from: accounts[2] });

    const latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await expect(SAMContractGas.addListing(LFGFireNFT.address, account2TokenIds[0], 0, "20000000", latestBlock["timestamp"] + 1, 3600 * 24,
      0, 0, { from: accounts[2] })).to.be.revertedWith("FireNFT can only sell for LFG");
  });
});
