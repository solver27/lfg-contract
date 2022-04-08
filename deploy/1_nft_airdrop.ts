import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

async function deploy() {
  const LFGFireNFT: ContractFactory = await ethers.getContractFactory(
    "LFGFireNFT"
  );
  const lfgFireNft: Contract = await LFGFireNFT.deploy();
  await lfgFireNft.deployed();
  console.log("lfgNft deployed to: ", lfgFireNft.address);

  const NftAirdrop: ContractFactory = await ethers.getContractFactory(
    "NftAirdrop"
  );

  const nftAirdrop: Contract = await NftAirdrop.deploy(lfgFireNft.address);
  await nftAirdrop.deployed();
  console.log("NftAirdrop deployed to: ", nftAirdrop.address);
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
