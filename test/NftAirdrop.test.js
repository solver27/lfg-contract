const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGFireNFTArt = hre.artifacts.require("LFGFireNFT");
const NftAirdropArt = hre.artifacts.require("NftAirdrop");
const BN = require("bn.js");

describe("NftAirdrop", function () {
  let LFGFireNFT = null;
  let NftAirdrop = null;
  let accounts = ["", ""],
    owner;

  const airDropNftAmount = 1;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], owner] = await web3.eth.getAccounts();
      LFGFireNFT = await LFGFireNFTArt.new(owner);
      NftAirdrop = await NftAirdropArt.new(owner, LFGFireNFT.address);
      await LFGFireNFT.setMinter(NftAirdrop.address, true, {from: owner});
    } catch (err) {
      console.log(err);
    }
  });

  it("test claim NFT method", async function () {
    let latestBlock = await hre.ethers.provider.getBlock("latest");
    await hre.network.provider.send("evm_setNextBlockTimestamp", [latestBlock["timestamp"] + 1000]);
    await hre.network.provider.send("evm_mine");
    await NftAirdrop.addWhitelists([accounts[1]], {from: owner});

    let minterResult = await LFGFireNFT.minters(NftAirdrop.address);
    console.log("Get minter result ", minterResult.toString());

    const whitelistInfo = await NftAirdrop.whitelistPools(accounts[1]);
    expect(new BN(whitelistInfo.claimed).toString()).to.equal("0");

    const claimTokenId = "2";

    // Claim the token before mint
    await expect(NftAirdrop.claimDistribution(claimTokenId, {from: accounts[1]})).to.be.revertedWith(
      "ERC721: operator query for nonexistent token"
    );

    await LFGFireNFT.adminMint(10, NftAirdrop.address, {from: owner});
    let tokenIds = await LFGFireNFT.tokensOfOwner(NftAirdrop.address);
    console.log("Tokens of airdrop contract: ", JSON.stringify(tokenIds));

    await NftAirdrop.claimDistribution(claimTokenId, {from: accounts[1]});

    tokenIds = await LFGFireNFT.tokensOfOwner(NftAirdrop.address);
    console.log("Tokens of airdrop contract: ", JSON.stringify(tokenIds));

    const whitelistInfoAfter = await NftAirdrop.whitelistPools(accounts[1]);
    expect(whitelistInfoAfter.claimed.toString()).to.equal("true");

    const nftBalance = await LFGFireNFT.balanceOf(accounts[1]);
    console.log("nftBalance ", nftBalance.toString());
    expect(new BN(nftBalance).toString()).to.equal(airDropNftAmount.toString());

    let claimedToken = await LFGFireNFT.tokensOfOwner(accounts[1]);
    assert.equal(claimedToken[0], claimTokenId);

    // User try to claim again, it should revert.
    await expect(NftAirdrop.claimDistribution("3", {from: accounts[1]})).to.be.revertedWith("User already claimed NFT");
  });
});
