const {BigNumber} = require("bignumber.js");
const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGFireNFTArt = hre.artifacts.require("LFGFireNFT");
const UserBlackListArt = hre.artifacts.require("UserBlackList");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftWhiteListArt = hre.artifacts.require("NftWhiteList");
const SAMConfigArt = hre.artifacts.require("SAMConfig");
const SAMContractArt = hre.artifacts.require("SAMContract");
const BurnTokenArt = hre.artifacts.require("BurnToken");

describe("SAMContract", function () {
  let LFGToken = null;
  let UserBlackList = null;
  let LFGNFT = null;
  let LFGFireNFT = null;
  let NftWhiteList = null;
  let SAMConfig = null;
  let SAMContract = null;
  let BurnToken = null;
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
      LFGToken = await LFGTokenArt.new("LFG Token", "LFG", "1000000000000000000000000000", owner);

      UserBlackList = await UserBlackListArt.new(owner);

      LFGNFT = await LFGNFTArt.new(owner, UserBlackList.address);

      LFGFireNFT = await LFGFireNFTArt.new();

      NftWhiteList = await NftWhiteListArt.new(owner);

      SAMConfig = await SAMConfigArt.new(owner, revenueAddress, burnAddress);

      SAMContract = await SAMContractArt.new(owner, LFGToken.address, NftWhiteList.address, SAMConfig.address);

      // make sure the default fee rate is discounted.
      const feeRateResult = await SAMContract.feeRate();
      assert.equal(feeRateResult.toString(), "125");

      // This one must call from owner
      await NftWhiteList.setNftContractWhitelist(LFGNFT.address, true, {
        from: owner,
      });
      await NftWhiteList.setNftContractWhitelist(LFGFireNFT.address, true, {
        from: owner,
      });

      // 2.5% fee, 50% of the fee burn, 10% royalties fee.
      await SAMContract.updateFeeRate(250, {from: owner});
      await SAMConfig.setRoyaltiesFeeRate(1000, {from: owner});

      BurnToken = await BurnTokenArt.new(owner, LFGToken.address, burnAddress1);
      await BurnToken.setOperator(SAMContract.address, true, {from: owner});
    } catch (err) {
      console.log(err);
    }
  });

  it("test buy now feature", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(accounts[2], 1, {from: accounts[2]});
    await LFGNFT.mint(accounts[2], 2, {from: accounts[2]});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContract.address, 1, {from: accounts[2]});

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await expect(
      SAMContract.addListing(
        LFGNFT.address,
        account2TokenIds[0],
        2, // copies
        0,
        "20000000",
        latestBlock["timestamp"] + 1,
        3600 * 24,
        0,
        0,
        {from: accounts[2]}
      )
    ).to.be.revertedWith("ERC721 doesn't support copies");

    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[0],
      1, // copies
      0, // Fixed price mode
      "20000000",
      0, // Fixed price don't need start time
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(accounts[1], testDepositAmount, {from: owner});

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("account 1 balance ", balance.toString());

    await LFGToken.approve(SAMContract.address, testDepositAmount, {
      from: accounts[1],
    });

    await expect(SAMContract.placeBid(listingId, "10000000", {from: accounts[1]})).to.be.revertedWith(
      "Can only bid for listing on auction"
    );

    await expect(SAMContract.buyNow(listingId, {from: accounts[2]})).to.be.revertedWith("Buyer cannot be seller");

    await SAMContract.buyNow(listingId, {from: accounts[1]});

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "2");

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    const account1Tokens = await SAMContract.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));

    balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.equal(balanceOfAccount2.toString(), "20000000");

    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    let burnAmount = await LFGToken.balanceOf(burnAddress);
    console.log("Burn amount ", burnAmount.toString());
    assert.equal(burnAmount.toString(), "250000");
  });

  it("test auction and bidding", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContract.address, account2TokenIds[0], {
      from: accounts[2],
    });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[0],
      1, // copies
      1, // sell mode auction
      "10000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);

    let listingId = listingResult[0];

    const testDepositAmount = "100000000000000000000000";
    for (let accountId = 3; accountId < 6; ++accountId) {
      await LFGToken.transfer(accounts[accountId], testDepositAmount, {
        from: owner,
      });
      await LFGToken.approve(SAMContract.address, testDepositAmount, {
        from: accounts[accountId],
      }); // to charge fees
    }

    await expect(SAMContract.placeBid(listingId, "10000000", {from: accounts[3]})).to.be.revertedWith(
      "Bid price too low"
    );

    await expect(SAMContract.placeBid(listingId, "11000000", {from: accounts[2]})).to.be.revertedWith(
      "Bidder cannot be seller"
    );

    const acc3BalanceBeforeBid = await LFGToken.balanceOf(accounts[3]);

    await SAMContract.placeBid(listingId, "11000000", {from: accounts[3]});

    const acc3BalanceAfterBid = await LFGToken.balanceOf(accounts[3]);
    // Verify the amount is deducted
    assert.equal(acc3BalanceAfterBid.toString(), "99999999999999989000000");

    await expect(SAMContract.placeBid(listingId, "11000000", {from: accounts[4]})).to.be.revertedWith(
      "Bid price too low"
    );

    await SAMContract.placeBid(listingId, "12000000", {from: accounts[4]});
    await SAMContract.placeBid(listingId, "15000000", {from: accounts[5]});

    const biddings = await SAMContract.biddingOfAddr(accounts[3]);
    // Because the bidding was removed if other bidding with higher price
    assert.equal(biddings.length, 0);

    const acc3BalanceAfterOverTakeBid = await LFGToken.balanceOf(accounts[3]);
    // account 3 should has been fefunded and its balance goes back to original balance
    assert.equal(acc3BalanceBeforeBid.toString(), acc3BalanceAfterOverTakeBid.toString());
    assert.equal(acc3BalanceAfterOverTakeBid.toString(), testDepositAmount);

    let biddingsOfAddr5 = await SAMContract.biddingOfAddr(accounts[5]);

    await expect(SAMContract.claimNft(biddingsOfAddr5[0], {from: accounts[5]})).to.be.revertedWith(
      "The bidding period haven't complete"
    );

    latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 3601 * 24]);
    await hre.network.provider.send("evm_mine");

    await expect(SAMContract.claimNft(biddingsOfAddr5[0], {from: accounts[3]})).to.be.revertedWith(
      "Only bidder can claim NFT"
    );

    await SAMContract.claimNft(biddingsOfAddr5[0], {from: accounts[5]});
    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    biddingsOfAddr5 = await SAMContract.biddingOfAddr(accounts[5]);
    assert.equal(biddingsOfAddr5.length, 0);

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.equal(balanceOfAccount2.toString(), "35000000");

    // Account 3 bid failed, should be auto refunded
    let balanceOfAccount3 = await LFGToken.balanceOf(accounts[3]);
    console.log("Balance of account 3 ", balanceOfAccount3.toString());
    assert.equal(balanceOfAccount3.toString(), testDepositAmount);

    let burnAmount = await LFGToken.balanceOf(burnAddress);
    console.log("Burn amount ", burnAmount.toString());
    assert.equal(burnAmount.toString(), "437500");

    let revenueAmount = await SAMContract.revenueAmount();
    assert.equal(revenueAmount.toString(), "437500");

    let revenueBalance = await LFGToken.balanceOf(revenueAddress);
    console.log("Revenue account balance ", revenueBalance.toString());
    assert.equal(revenueBalance.toString(), "437500");
  });

  it("test remove listing", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(accounts[2], 3, {from: accounts[2]});
    await LFGNFT.mint(accounts[2], 4, {from: accounts[2]});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContract.address, account2TokenIds[0], {
      from: accounts[2],
    });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[0],
      1, // copies
      1, // Auction
      "10000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult for remove ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];
    const lstDetail = await SAMContract.listingRegistry(listingId);
    console.log("listing detail ", lstDetail);

    await expect(SAMContract.removeListing(listingId, {from: accounts[2]})).to.be.revertedWith(
      "The listing haven't expired"
    );

    latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 3601 * 48]);
    await hre.network.provider.send("evm_mine");

    await expect(SAMContract.removeListing(listingId, {from: accounts[1]})).to.be.revertedWith(
      "Only seller can remove"
    );

    await SAMContract.removeListing(listingId, {from: accounts[2]});
    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 0);

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));
  });

  it("test dutch auction ", async function () {
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContract.address, account2TokenIds[0], {
      from: accounts[2],
    });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[0],
      1, // copies
      2,
      "10000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      3600,
      100000,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await expect(SAMContract.removeListing(listingId, {from: accounts[2]})).to.be.revertedWith(
      "The listing haven't expired"
    );

    latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 3600 * 12]);
    await hre.network.provider.send("evm_mine");

    let currentPrice = await SAMContract.getPrice(listingId);
    console.log("currentPrice ", currentPrice.toString());

    await SAMContract.buyNow(listingId, {from: accounts[1]});

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[1], "4");

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    const account1Tokens = await SAMContract.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));

    balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.equal(balanceOfAccount2.toString(), "43800000");

    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    // The price is 8800000, charge 2.5% fee, and burn 50% of the fee, so burn 110000, revenue 110000
    let burnAccBal = await LFGToken.balanceOf(burnAddress);
    console.log("burnAccBal ", burnAccBal.toString());
    assert.equal(burnAccBal.toString(), "547500");

    let totalBurnAmount = await SAMContract.totalBurnAmount();
    console.log("totalBurnAmount ", burnAccBal.toString());
    assert.equal(totalBurnAmount.toString(), "547500");

    // Increased renuve 8800000 * 2.5% * 50% = 110000
    let revenueAmount = await SAMContract.revenueAmount();
    assert.equal(revenueAmount.toString(), "547500");

    let revenueBalance = await LFGToken.balanceOf(revenueAddress);
    console.log("Revenue account balance ", revenueBalance.toString());
    assert.equal(revenueBalance.toString(), "547500");
  });

  it("test royalties payment after sell", async function () {
    let supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGNFT.mint(accounts[2], 5, {from: accounts[2]});

    supply = await LFGNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    const lastIndex = account2TokenIds.length - 1;

    await LFGNFT.setRoyalty(account2TokenIds[lastIndex], accounts[6], 2000, {
      from: accounts[2],
    });

    await LFGNFT.approve(SAMContract.address, account2TokenIds[lastIndex], {
      from: accounts[2],
    });

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[lastIndex],
      1, // copies
      0,
      "20000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    await expect(
      LFGNFT.setRoyalty(account2TokenIds[lastIndex], accounts[6], 2000, {
        from: accounts[2],
      })
    ).to.be.revertedWith("NFT: Cannot set royalty after transfer");

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(accounts[1], testDepositAmount, {from: owner});

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("account 1 balance ", balance.toString());

    await LFGToken.approve(SAMContract.address, testDepositAmount, {
      from: accounts[1],
    });

    await SAMContract.buyNow(listingId, {from: accounts[1]});

    let account1Tokens = await SAMContract.addrTokens(accounts[1]);
    console.log("Escrow tokens of account 1 ", JSON.stringify(account1Tokens));
    assert.equal(account1Tokens.toString(), "0");

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account 2 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "3");

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.equal(balanceOfAccount2.toString(), "59800000"); // 43800000 + 1600000

    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    let balanceOfAccount6 = await LFGToken.balanceOf(accounts[6]);
    console.log("Balance of account 6 ", balanceOfAccount6.toString());
    assert.equal(balanceOfAccount6.toString(), "3600000"); // Because charged 10% royalties fee, so 4000000 becomes 3600000

    // Incresed revenue = 20000000 * 2.5% * 50% + 20000000 * 20% * 10% = 650000
    // Last step revenue is 547500, so total revenue is 547500 + 650000 = 1197500
    let revenueAmount = await SAMContract.revenueAmount();
    assert.equal(revenueAmount.toString(), "1197500");

    let revenueBalance = await LFGToken.balanceOf(revenueAddress);
    console.log("Revenue account balance ", revenueBalance.toString());
    assert.equal(revenueBalance.toString(), "1197500");
  });

  it("test burn token when fire NFT was sold by fixed price", async function () {
    console.log("BurnToken ", BurnToken.address);
    // Top up burn contract
    await LFGToken.transfer(BurnToken.address, "100000000000000000000000", {
      from: owner,
    });
    // set burn rate to 10%
    await BurnToken.setBurnRate(1000, {from: owner});
    await SAMContract.setBurnTokenContract(BurnToken.address, {from: owner});

    await SAMConfig.setFireNftContractAddress(LFGFireNFT.address, {from: owner});

    let supply = await LFGFireNFT.totalSupply();
    console.log("supply ", supply.toString());

    await LFGFireNFT.adminMint(2, accounts[2], {from: accounts[0]});

    supply = await LFGFireNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGFireNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGFireNFT.approve(SAMContract.address, 1, {from: accounts[2]});

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContract.addListing(
      LFGFireNFT.address,
      account2TokenIds[0],
      1, // copies
      0,
      "20000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    const testDepositAmount = "100000000000000000000000";
    await LFGToken.transfer(accounts[1], testDepositAmount, {from: owner});

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("account 1 balance ", balance.toString());

    await LFGToken.approve(SAMContract.address, testDepositAmount, {
      from: accounts[1],
    });

    await SAMContract.buyNow(listingId, {from: accounts[1]});

    let account1TokenIds = await LFGFireNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[0], "1");

    account2TokenIds = await LFGFireNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds[0], "2");

    let balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());

    balanceOfAccount2 = await LFGToken.balanceOf(accounts[2]);
    console.log("Balance of account 2 ", balanceOfAccount2.toString());
    assert.equal(balanceOfAccount2.toString(), "79800000");

    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    assert.equal(listingResult.length, 0);

    // Check on the burn address 1 which is for the burn token contract
    let burnAddrBal = await LFGToken.balanceOf(burnAddress1);
    console.log("Burn address balance ", burnAddrBal.toString());
    assert.equal(burnAddrBal.toString(), "2000000");

    // Check the burn amount
    let totalBurnAmount = await BurnToken.totalBurnAmount();
    assert.equal(totalBurnAmount.toString(), "2000000");
  });

  it("test burn token when fire NFT was sold by auction", async function () {
    let supply = await LFGFireNFT.totalSupply();
    console.log("supply ", supply.toString());
    let account2TokenIds = await LFGFireNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGFireNFT.approve(SAMContract.address, account2TokenIds[0], {from: accounts[2]});

    let latestBlock = await hre.ethers.provider.getBlock("latest");
    console.log("latestBlock ", latestBlock);

    await SAMContract.addListing(
      LFGFireNFT.address,
      account2TokenIds[0],
      1, // copies
      1, // auction
      "20000000",
      latestBlock["timestamp"] + 1,
      3600 * 24,
      0,
      0,
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];

    await SAMContract.placeBid(listingId, 30000000, {from: accounts[1]});

    const biddings = await SAMContract.biddingOfAddr(accounts[1]);
    // Because the bidding was removed if other bidding with higher price
    assert.equal(biddings.length, 1);

    latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 3601 * 24]);
    await hre.network.provider.send("evm_mine");

    await SAMContract.claimNft(biddings[0], {from: accounts[1]});

    let account1TokenIds = await LFGFireNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account 1 ", JSON.stringify(account1TokenIds));
    assert.equal(account1TokenIds[1], "2");

    account2TokenIds = await LFGFireNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account0 ", JSON.stringify(account2TokenIds));
    assert.equal(account2TokenIds.length, 0);

    // Check on the burn address 1 which is for the burn token contract
    let burnAddrBal = await LFGToken.balanceOf(burnAddress1);
    console.log("Burn address balance ", burnAddrBal.toString());
    assert.equal(burnAddrBal.toString(), "5000000"); // 2000000 + 30000000 * 10% = 2000000 + 30000000

    // Check the burn amount
    let totalBurnAmount = await BurnToken.totalBurnAmount();
    assert.equal(totalBurnAmount.toString(), "5000000");
  });

  it("test remove listing for fixed price ", async function () {
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    await LFGNFT.approve(SAMContract.address, account2TokenIds[0], {
      from: accounts[2],
    });

    await SAMContract.addListing(
      LFGNFT.address,
      account2TokenIds[0],
      1, // copies
      0, // fixed price
      "10000000",
      0, // The start time no use
      0, // Duration
      0, // _discountInterval
      0, // _discountAmount
      {from: accounts[2]}
    );

    let listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult for remove ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 1);
    let listingId = listingResult[0];
    const lstDetail = await SAMContract.listingRegistry(listingId);
    //console.log("listing detail ", lstDetail);

    await expect(SAMContract.removeListing(listingId, {from: accounts[1]})).to.be.revertedWith(
      "Only seller can remove"
    );

    await SAMContract.removeListing(listingId, {from: accounts[2]});
    listingResult = await SAMContract.listingOfAddr(accounts[2]);
    console.log("getListingResult ", JSON.stringify(listingResult));
    assert.equal(listingResult.length, 0);

    account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 after remove listing ", JSON.stringify(account2TokenIds));
  });

  it("test add user to blacklist", async function () {
    let account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    console.log("tokenIds of account2 ", JSON.stringify(account2TokenIds));

    let getOwnerResult = await LFGNFT.ownerOf(account2TokenIds[0]);
    console.log("getOwner result ", getOwnerResult);

    // blacklist the user
    await UserBlackList.setUserBlackList([accounts[2]], [true], {from: owner});

    await LFGNFT.approve(SAMContract.address, account2TokenIds[0], {from: accounts[2]});

    await expect(
      SAMContract.addListing(
        LFGNFT.address,
        account2TokenIds[0],
        1, // copies
        0, // fixed price
        "10000000",
        0, // The start time no use
        0, // Duration
        0, // _discountInterval
        0, // _discountAmount
        {from: accounts[2]}
      )
    ).to.be.revertedWith("from address is blacklisted");
  });
});
