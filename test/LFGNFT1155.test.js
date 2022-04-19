const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const LFGNFT1155Art = hre.artifacts.require("LFGNFT1155");
const BN = require("bn.js");
const {createImportSpecifier} = require("typescript");

describe("LFGNFT1155", function () {
  let LFGNFT1155 = null;
  let accounts = ["", "", "", ""],
    owner;

  const baseURI = "https://gateway.pinata.cloud/ipfs/QmWNPuFyQLa2EjGPVAhA8veFc6yuTwNVEeGRgkCKk4NW5Q/";

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], accounts[2], accounts[3], owner] = await web3.eth.getAccounts();
      LFGNFT1155 = await LFGNFT1155Art.new(owner, baseURI);
    } catch (err) {
      console.log(err);
    }
  });

  it("test NFT 1155 mint", async function () {
    const collectionTag = web3.utils.asciiToHex("CryoptKitty");

    await expect(
      LFGNFT1155.create(accounts[1], 10, collectionTag, {
        from: accounts[1],
      })
    ).to.be.revertedWith("Collection doesn't exist");

    await LFGNFT1155.createCollection(collectionTag, {
      from: accounts[1],
    });

    let result = await LFGNFT1155.create(accounts[1], 10, collectionTag, {
      from: accounts[1],
    });

    console.log(JSON.stringify(result));
    let id = result["logs"][0]["args"]["id"];
    console.log("id: ", id.toString());

    let royaltyInfo = await LFGNFT1155.royaltyInfo(id, 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    // Before set royalty, it should be 0
    assert.equal(royaltyInfo["royaltyAmount"], "0");

    // set 10% royalty
    await LFGNFT1155.setRoyalty(id, accounts[1], 1000, {from: accounts[1]});

    let tokenUri = await LFGNFT1155.uri(id);
    console.log("Token 1 uri: ", tokenUri);
    assert.equal(tokenUri, baseURI + "1");

    const nftBalance1 = await LFGNFT1155.balanceOf(accounts[1], id);
    console.log("nftBalance of account 1 ", nftBalance1.toString());
    assert.equal(nftBalance1.toString(), "10");

    // mint another 10
    await LFGNFT1155.mint(accounts[2], id, 10, collectionTag, {
      from: accounts[1],
    });
    let nftBalance2 = await LFGNFT1155.balanceOf(accounts[2], id);
    console.log("nftBalance of account 2 ", nftBalance2.toString());
    assert.equal(nftBalance2.toString(), "10");

    const token1Supply = await LFGNFT1155.tokenSupply(id);
    assert.equal(token1Supply.toString(), "20");

    await LFGNFT1155.safeTransferFrom(accounts[2], accounts[3], id, 5, collectionTag, {
      from: accounts[2],
    });

    nftBalance2 = await LFGNFT1155.balanceOf(accounts[2], id);
    console.log("nftBalance of account 2 ", nftBalance2.toString());
    assert.equal(nftBalance2.toString(), "5");

    let nftBalance3 = await LFGNFT1155.balanceOf(accounts[3], id);
    console.log("nftBalance of account 3 ", nftBalance2.toString());
    assert.equal(nftBalance3.toString(), "5");

    // let account1TokenIds = await LFGNFT1155.tokensOfOwner(accounts[1]);
    // console.log("tokenIds of account1 ", JSON.stringify(account1TokenIds));

    
    await expect(LFGNFT1155.setRoyalty(id, accounts[1], 1000, {from: accounts[2]})).to.be.revertedWith(
      "NFT: Invalid creator"
    );

    await expect(LFGNFT1155.setRoyalty(id, accounts[1], 1000, {from: accounts[1]})).to.be.revertedWith(
      "NFT: Cannot set royalty after transfer"
    );

    royaltyInfo = await LFGNFT1155.royaltyInfo(id, 10000);
    console.log("royaltyInfo ", JSON.stringify(royaltyInfo));

    assert.equal(royaltyInfo["receiver"], accounts[1]);
    assert.equal(royaltyInfo["royaltyAmount"], "1000");

    await expect(
      LFGNFT1155.create(accounts[2], 10, collectionTag, {
        from: accounts[2],
      })
    ).to.be.revertedWith("Only the same user can add to collection");

    await expect(
      LFGNFT1155.createBatch(accounts[2], 10, 0, collectionTag, {
        from: accounts[2],
      })
    ).to.be.revertedWith("Only the same user can add to collection");

    const collectionTagPok = web3.utils.asciiToHex("Pokemon");
    await LFGNFT1155.createCollection(collectionTagPok, {
      from: accounts[2],
    });

    await LFGNFT1155.createBatch(accounts[2], 10, 0, collectionTagPok, {
      from: accounts[2],
    });

    let getCollections = await LFGNFT1155.collections(collectionTagPok);
    console.log("Collections: ", JSON.stringify(getCollections));

    let collectionTokens = await LFGNFT1155.getCollectionTokens(collectionTagPok);
    console.log("Collections tokens: ", JSON.stringify(collectionTokens));

    // try to create the same token again.
    await expect(
      LFGNFT1155.createCollection(collectionTag, {
        from: accounts[1],
      })
    ).to.be.revertedWith("Collection already created");
  });
});
