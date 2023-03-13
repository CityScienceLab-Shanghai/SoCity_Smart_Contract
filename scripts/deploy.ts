import { ethers } from "hardhat";

import * as fs from 'fs'

async function deploy_token(){

  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy();

  console.log("Token address:", token.address);
  fs.writeFileSync('./../artifacts/contracts/Token.sol/address.txt', token.address);
}


async function main() {
  
  deploy_token()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
