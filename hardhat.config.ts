import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import * as dotenv from "dotenv";

dotenv.config();

const GOERLI_RPC_URL=process.env.GOERLI_RPC_URL || ""
const ALCHEMY_PRIVATE_KEY= process.env.ALCHEMY_PRIVATE_KEY || ""


const config: HardhatUserConfig = {
  defaultNetwork: "goerli",
  paths: {
    artifacts: './../artifacts',
  },
  networks: {
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [ ALCHEMY_PRIVATE_KEY]
    },
  },
  solidity: "0.8.18",
};

export default config;
