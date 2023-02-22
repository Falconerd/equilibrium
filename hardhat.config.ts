import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "hardhat-tracer";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  gasReporter: {
      enabled: false
  },
  networks: {
      hardhat: {
          mining: {
              //auto: false,
              //interval: 0,
          }
      }
  }
};

export default config;
