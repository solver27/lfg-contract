import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

if (!process.env.MULTISIG_PUBKEY)
  throw new Error("MULTISIG_PUBKEY missing from .env file");

async function deploy() {
  // // LFG token contract
  // const LFGToken: ContractFactory = await ethers.getContractFactory("LFGToken");
  // const lfgToken: Contract = await LFGToken.deploy(
  //   "LFG Token",
  //   "LFG",
  //   "1000000000000000000000000000",
  //   process.env.MULTISIG_PUBKEY
  // );
  // await lfgToken.deployed();
  // console.log("LFGToken deployed to: ", lfgToken.address);

  // UserBlackList contract
  const UserBlackList: ContractFactory = await ethers.getContractFactory(
    "UserBlackList"
  );
  const userBlackList: Contract = await UserBlackList.deploy(
    process.env.MULTISIG_PUBKEY
  );
  await userBlackList.deployed();
  console.log("UserBlackList deployed to: ", userBlackList.address);

  // LFGNFT contract
  const LFGNFT: ContractFactory = await ethers.getContractFactory("LFGNFT");
  const lfgNft: Contract = await LFGNFT.deploy(
    process.env.MULTISIG_PUBKEY,
    userBlackList.address
  );
  await lfgNft.deployed();
  console.log("LFGNFT deployed to: ", lfgNft.address);

  // LFGNFT1155 contract
  const LFGNFT1155: ContractFactory = await ethers.getContractFactory(
    "LFGNFT1155"
  );
  const lfgNft1155: Contract = await LFGNFT1155.deploy(
    process.env.MULTISIG_PUBKEY,
    userBlackList.address,
    ""
  );
  await lfgNft1155.deployed();
  console.log("LFGNFT1155 deployed to: ", lfgNft1155.address);
}

async function main(): Promise<void> {
  await deploy();
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
