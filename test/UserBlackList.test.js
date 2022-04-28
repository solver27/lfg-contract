const {assert, expect} = require("chai");
const hre = require("hardhat");
const {web3} = require("hardhat");
const UserBlackListArt = hre.artifacts.require("UserBlackList");

describe("UserBlackList", function () {
  let UserBlackList = null;
  let accounts = ["", ""],
    owner,
    operator;

  before("Deploy contract", async function () {
    try {
      [accounts[0], accounts[1], owner, operator] = await web3.eth.getAccounts();
      UserBlackList = await UserBlackListArt.new(owner);
    } catch (err) {
      console.log(err);
    }
  });

  it("test blacklist feature", async function () {
    let isWhitelisted = await UserBlackList.userBlackLists(accounts[1]);
    assert.equal(isWhitelisted, false);

    let isOperator = await UserBlackList.operators(operator);
    assert.equal(isOperator, false);

    await expect(UserBlackList.setUserBlackList([accounts[1]], [true], {from: operator})).to.be.revertedWith(
      "Invalid operator or owner"
    );

    await UserBlackList.setOperator(operator, true, {from: owner});
    isOperator = await UserBlackList.operators(operator);
    assert.equal(isOperator, true);

    await UserBlackList.setUserBlackList([accounts[1]], [true], {from: operator});
    isWhitelisted = await UserBlackList.userBlackLists(accounts[1]);
    assert.equal(isWhitelisted, true);
  });
});
