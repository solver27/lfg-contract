const {expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGTokenArt = hre.artifacts.require("LFGToken");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const NftEscrowArt = hre.artifacts.require("NftEscrow");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("NftEscrow", function () {
  let LFGToken = null;
  let LFGNFT = null;
  let NftEscrow = null;
  let accounts = ["", ""],
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], minter] = await web3.eth.getAccounts();
      LFGToken = await LFGTokenArt.new("LFG Token",
      "LFG",
      "1000000000000000000000000000", minter);

      LFGNFT = await LFGNFTArt.new();
      NftEscrow = await NftEscrowArt.new(minter, LFGToken.address);

      await LFGNFT.setMinter(minter, true);

      await NftEscrow.setOperator(minter, {from: minter}); // During construct owner changed to minter

      const operatorResult = await NftEscrow.operator();
      console.log("get operator: ", operatorResult.toString());
  
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

    const operatorResult = await NftEscrow.operator();
    console.log("get operator: ", operatorResult.toString());

    await NftEscrow.depositNft(accounts[0], LFGNFT.address, 1, {from: minter});
    tokenIds = await LFGNFT.tokensOfOwner(accounts[0]);
    console.log("tokenIds ", JSON.stringify(tokenIds));

    await NftEscrow.transferNft(accounts[0], LFGNFT.address, 1, {from: minter});
    tokenIds = await LFGNFT.tokensOfOwner(accounts[0]);
    console.log("tokenIds ", JSON.stringify(tokenIds));
  });

  it("test LFG Escrow", async function () {
    const testDepositAmount = "100000000000000000000000";
    const halfDepositAmount = "50000000000000000000000";

    await LFGToken.transfer(accounts[0], testDepositAmount);
    await LFGToken.transfer(accounts[1], testDepositAmount);

    let balance = await LFGToken.balanceOf(accounts[1]);
    console.log("balance ", balance.toString());

    await LFGToken.increaseAllowance(NftEscrow.address, testDepositAmount, { from: accounts[1] });

    await NftEscrow.depositToken(accounts[1], halfDepositAmount, {from: minter});

    balance = await LFGToken.balanceOf(accounts[1]);
    console.log("balance ", balance.toString());

    await NftEscrow.transferToken(accounts[1], accounts[1], halfDepositAmount, {from: minter});

    await NftEscrow.claimToken(accounts[1], {from: minter});

    balance = await LFGToken.balanceOf(accounts[1]);
    console.log("balance ", balance.toString());
  });
});
