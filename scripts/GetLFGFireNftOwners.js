Web3 = require("web3");
var fs = require("fs");
const {assert} = require("chai");

var jsonFile = "./artifacts/contracts/LFGFireNFT.sol/LFGFireNFT.json";
var parsed = JSON.parse(fs.readFileSync(jsonFile));
var abi = parsed.abi;

const testWeb3 = new Web3("https://bsc-dataseed4.binance.org/");

const fireNftInst = new testWeb3.eth.Contract(abi, "0x8d06c569BEaC76f2cF7A54E61157d1C461B9BF85");
let totalNFTCount = 711;

const delay = (ms) => new Promise((res) => setTimeout(res, ms));

async function getFunction(owners) {
  for (tokenId = 1; tokenId <= totalNFTCount; ++tokenId) {
    fireNftInst.methods.ownerOf(tokenId).call(function (err, result) {
      owners.push(result);
    });

    await delay(500);
  }
}

(async () => {
  let owners = [];
  await getFunction(owners);
  assert.equal(owners.length, totalNFTCount);

  for (let index in owners) {
    let tokenId = parseInt(index) + 1;
    console.log("TokenId, ", tokenId, ", owner,", owners[index]);
  }
})();
