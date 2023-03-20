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

//deploy the vote_original.sol
async function deploy_vote(){
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account", deployer.address);

  const Vote = await ethers.getContractFactory("VoteMVP");
  const vote = await Vote.deploy();

  console.log("Vote address:", vote.address); //部署之后更新的address
  fs.writeFileSync('./../artifacts/contracts/Vote.sol/address.txt', vote.address); //写入address文件
}


async function main() {
  //deploy_token()
  deploy_vote();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
