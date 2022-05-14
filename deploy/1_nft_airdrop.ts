import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

if (!process.env.MULTISIG_PUBKEY)
  throw new Error("MULTISIG_PUBKEY missing from .env file");

async function deploy() {
  const LFGFireNFT: ContractFactory = await ethers.getContractFactory(
    "LFGFireNFT"
  );
  const lfgFireNft: Contract = await LFGFireNFT.deploy(
    process.env.MULTISIG_PUBKEY
  );
  await lfgFireNft.deployed();
  console.log("lfgFireNft deployed to: ", lfgFireNft.address);

  const NftAirdrop: ContractFactory = await ethers.getContractFactory(
    "NftAirdrop"
  );

  const nftAirdrop: Contract = await NftAirdrop.deploy(
    process.env.MULTISIG_PUBKEY,
    lfgFireNft.address
  );
  await nftAirdrop.deployed();
  console.log("NftAirdrop deployed to: ", nftAirdrop.address);

  // NFT distribute
  const NftDistribute: ContractFactory = await ethers.getContractFactory(
    "NftDistribute"
  );

  const nftDistribute: Contract = await NftDistribute.deploy(
    process.env.MULTISIG_PUBKEY,
    lfgFireNft.address
  );
  await nftDistribute.deployed();
  console.log("NftDistribute deployed to: ", nftDistribute.address);
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
