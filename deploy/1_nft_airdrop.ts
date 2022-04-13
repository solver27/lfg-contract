import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

async function deploy() {
  const LFGFireNFT: ContractFactory = await ethers.getContractFactory(
    "LFGFireNFT"
  );
  const lfgFireNft: Contract = await LFGFireNFT.deploy();
  await lfgFireNft.deployed();
  console.log("lfgFireNft deployed to: ", lfgFireNft.address);

  const LFGNFT: ContractFactory = await ethers.getContractFactory("LFGNFT");
  const lfgNft: Contract = await LFGNFT.deploy();
  await lfgNft.deployed();
  console.log("lfgNft deployed to: ", lfgNft.address);

  const NftAirdrop: ContractFactory = await ethers.getContractFactory(
    "NftAirdrop"
  );

  const nftAirdrop: Contract = await NftAirdrop.deploy(lfgFireNft.address);
  await nftAirdrop.deployed();
  console.log("nftAirdrop deployed to: ", nftAirdrop.address);
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
