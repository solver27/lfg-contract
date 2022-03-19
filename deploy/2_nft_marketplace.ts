import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

async function deploy() {
  // LFG token contract
  const LFGToken: ContractFactory = await ethers.getContractFactory("LFGToken");
  const lfgToken: Contract = await LFGToken.deploy(
    "LFG Token",
    "LFG",
    "1000000000000000000000000000",
    process.env.MULTISIG_PUBKEY
  );
  await lfgToken.deployed();
  console.log("LFGToken deployed to: ", lfgToken.address);

  // LFGNFT contract
  const LFGNFT: ContractFactory = await ethers.getContractFactory("LFGNFT");
  const lfgNft: Contract = await LFGNFT.deploy();
  await lfgNft.deployed();
  console.log("LFGNFT deployed to: ", lfgNft.address);

  // Nft whitelist contract
  const NftWhiteList: ContractFactory = await ethers.getContractFactory(
    "NftWhiteList"
  );
  const nftWhiteList: Contract = await NftWhiteList.deploy(
    "0x3ca3822163D049364E67bE19a0D3B2F03B7e99b5"
  );
  await nftWhiteList.deployed();
  console.log("NftWhiteList deployed to: ", nftWhiteList.address);

  // SAMContract uses token
  const SAMContract: ContractFactory = await ethers.getContractFactory(
    "SAMContract"
  );

  const samContract: Contract = await SAMContract.deploy(
    "0x3ca3822163D049364E67bE19a0D3B2F03B7e99b5", // owner address
    "0x53c54E27DEc0Fa40ac02B032c6766Ce8E04A2A70", // lfgToken.address
    nftWhiteList.address, // Whitelist contract
    "0xf197c5bC13383ef49511303065d39b33DC063f72", // burn address
    "0x08955A4e6b4A543FE68479F5482739Ff4D625A16" // Revenue address
  );

  await samContract.deployed();
  console.log("SAMContract deployed to: ", samContract.address);

  // SAMContract uses gas
  const SAMContractGas: ContractFactory = await ethers.getContractFactory(
    "SAMContractGas"
  );

  const samContractGas: Contract = await SAMContractGas.deploy(
    "0x3ca3822163D049364E67bE19a0D3B2F03B7e99b5", // owner address
    "0xBC289f68248411754915E69a8a3d51599b857a8F" // White List contract
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
