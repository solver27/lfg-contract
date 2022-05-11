const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGNFTArt = hre.artifacts.require("LFGNFT");
const UserBlackListArt = hre.artifacts.require("UserBlackList");

describe("LFGNFT", function () {
  let LFGNFT = null;
  let UserBlackList = null;
  let accounts = ["", "", ""],
    owner,
    minter;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], owner, minter] = await web3.eth.getAccounts();
      UserBlackList = await UserBlackListArt.new(owner);
      LFGNFT = await LFGNFTArt.new(owner, UserBlackList.address);
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT Royalties", async function () {
    await LFGNFT.mint(accounts[1], 1, {from: accounts[1]});
    //console.log("tx: ", JSON.stringify(tx));
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

  it("test admin mint", async function () {
    const tokenURIs = ["ipfs://a", "ipfs://b", "ipfs://c"];
    await expect(LFGNFT.adminMint(tokenURIs, accounts[2], {from: accounts[2]})).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );
    let adminMintTx = await LFGNFT.adminMint(tokenURIs, accounts[2], {from: owner});
    console.log("adminMintTx: ", JSON.stringify(adminMintTx));
    const nftBalance = await LFGNFT.balanceOf(accounts[2]);
    assert.equal(nftBalance.toString(), 3);
    const account2TokenIds = await LFGNFT.tokensOfOwner(accounts[2]);
    for (let index in account2TokenIds) {
      const tokenURI = await LFGNFT.tokenURI(account2TokenIds[index]);
      console.log("Token id ", account2TokenIds[index].toString(), " URI ", tokenURI);
      assert.equal(tokenURI, tokenURIs[index]);
    }
  });

  it("test blacklist", async function () {
    await UserBlackList.setUserBlackList([accounts[1]], [true], {from: owner});
    await expect(LFGNFT.mint(accounts[1], 1, {from: accounts[1]})).to.be.revertedWith("User is blacklisted");

    let account1TokenIds = await LFGNFT.tokensOfOwner(accounts[1]);
    console.log("tokenIds of account1 ", JSON.stringify(account1TokenIds));

    await expect(
      LFGNFT.transferFrom(accounts[1], accounts[2], account1TokenIds[0], {from: accounts[1]})
    ).to.be.revertedWith("from address is blacklisted");
  });
});
