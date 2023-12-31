import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

if (!process.env.MULTISIG_PUBKEY)
  throw new Error("MULTISIG_PUBKEY missing from .env file");

async function deploy() {
  // Nft whitelist contract
  const NftWhiteList: ContractFactory = await ethers.getContractFactory(
    "NftWhiteList"
  );
  const nftWhiteList: Contract = await NftWhiteList.deploy(
    process.env.MULTISIG_PUBKEY
  );
  await nftWhiteList.deployed();
  console.log("NftWhiteList deployed to: ", nftWhiteList.address);

  const SAMConfigContract: ContractFactory = await ethers.getContractFactory(
    "SAMConfig"
  );
  const samConfigContract: Contract = await SAMConfigContract.deploy(
    process.env.MULTISIG_PUBKEY,
    "0x08955A4e6b4A543FE68479F5482739Ff4D625A16", // Revenue address
    "0xf197c5bC13383ef49511303065d39b33DC063f72" // burn address
  );
  await samConfigContract.deployed();
  console.log("SAMConfigContract deployed to: ", samConfigContract.address);

  // SAMContract uses token
  const SAMContract: ContractFactory = await ethers.getContractFactory(
    "SAMContract"
  );

  const samContract: Contract = await SAMContract.deploy(
    process.env.MULTISIG_PUBKEY, // owner address
    "0x53c54E27DEc0Fa40ac02B032c6766Ce8E04A2A70", // lfgToken.address
    nftWhiteList.address, // Whitelist contract
    samConfigContract.address // SAMConfig address
  );

  await samContract.deployed();
  console.log("SAMContract deployed to: ", samContract.address);

  // SAMContract uses gas
  const SAMContractGas: ContractFactory = await ethers.getContractFactory(
    "SAMContractGas"
  );

  const samContractGas: Contract = await SAMContractGas.deploy(
    process.env.MULTISIG_PUBKEY, // owner address
    nftWhiteList.address, // White List contract
    samConfigContract.address // SAMConfig address
  );

  await samContractGas.deployed();
  console.log("SAMContractGas deployed to: ", samContractGas.address);
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
