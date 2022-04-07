import "@nomiclabs/hardhat-ethers";

import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat"; // Optional (for `node <script>`)

async function deploy() {
  // SAMLazyMint lazy mint uses token
  const SAMLazyMint: ContractFactory = await ethers.getContractFactory(
    "SAMLazyMint"
  );

  const samLazyMint: Contract = await SAMLazyMint.deploy(
    "0x3ca3822163D049364E67bE19a0D3B2F03B7e99b5", // owner address
    "0x53c54E27DEc0Fa40ac02B032c6766Ce8E04A2A70", // lfgToken.address
    "0x62bc3AA2b12E0f2162507D6104ebCeb101f66fBD", // nft contract address
    "0xf197c5bC13383ef49511303065d39b33DC063f72", // burn address
    "0x08955A4e6b4A543FE68479F5482739Ff4D625A16" // Revenue address
  );

  await samLazyMint.deployed();
  console.log("SAMLazyMint deployed to: ", samLazyMint.address);
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
