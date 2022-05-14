const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGFireNFTArt = hre.artifacts.require("LFGFireNFT");
const NftDistributeArt = hre.artifacts.require("NftDistribute");
const BN = require("bn.js");

describe("NftDistribute", function () {
  let LFGFireNFT = null;
  let NftDistribute = null;
  let accounts = ["", "", "", ""],
    owner;

  const airDropNftAmount = 1;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], accounts[3], owner] = await web3.eth.getAccounts();
      LFGFireNFT = await LFGFireNFTArt.new(owner);
      NftDistribute = await NftDistributeArt.new(owner, LFGFireNFT.address);
    } catch (err) {
      console.log(err);
    }
  });

  it("test distrubute", async function () {
    await LFGFireNFT.adminMint(10, NftDistribute.address, {from: owner});
    let tokenIds = await LFGFireNFT.tokensOfOwner(NftDistribute.address);
    console.log("Tokens of distribute contract: ", JSON.stringify(tokenIds));

    await expect(NftDistribute.distributeNft([accounts[1], accounts[2], accounts[3]], [3, 6, 8])).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );

    await NftDistribute.distributeNft([accounts[1], accounts[2], accounts[3]], [3, 6, 8], {from: owner});

    tokenIds = await LFGFireNFT.tokensOfOwner(NftDistribute.address);
    console.log("Tokens of airdrop contract: ", JSON.stringify(tokenIds));

    const nftBalance = await LFGFireNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());
    expect(new BN(nftBalance).toString()).to.equal(airDropNftAmount.toString());

    let claimedToken = await LFGFireNFT.tokensOfOwner(accounts[1]);
    assert.equal(claimedToken[0], "3");
  });

  it("test distrubute maximum", async function () {
    let maxDistribute = 250;
    await LFGFireNFT.adminMint(maxDistribute, NftDistribute.address, {from: owner});
    let tokenIds = await LFGFireNFT.tokensOfOwner(NftDistribute.address);
    console.log("Tokens of distribute contract: ", JSON.stringify(tokenIds));

    let addresses = [];
    let tokenToDistribute = [];
    for (let i = 0; i < maxDistribute; ++i) {
      addresses.push(accounts[3]);
      tokenToDistribute.push(tokenIds[i]);
    }
    console.log("addresses length ", addresses.length);
    await NftDistribute.distributeNft(addresses, tokenToDistribute, {from: owner});

    tokenIds = await LFGFireNFT.tokensOfOwner(NftDistribute.address);
    console.log("Tokens of airdrop contract: ", JSON.stringify(tokenIds));

    const nftBalance = await LFGFireNFT.balanceOf(accounts[3]);
    console.log("nftBalance ", nftBalance.toString());
    assert.equal(nftBalance.toString(), (maxDistribute + 1).toString());
  });
});
