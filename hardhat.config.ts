import '@openzeppelin/hardhat-upgrades';
import "@nomicfoundation/hardhat-toolbox-viem";
import { HardhatUserConfig } from "hardhat/config";
import * as dotenv from 'dotenv';

dotenv.config();

const accounts =
  process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] :
    process.env.MNEMONIC ? { mnemonic: process.env.MNEMONIC } :
      undefined;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
    ]
  },
  networks: {
    'optimism': {
      url: process.env.NETWORK_OPTIMISM_URL || 'https://mainnet.optimism.io',
      chainId: 10,
      accounts,
    },
    'optimism-sepolia': {
      url: process.env.NETWORK_OPTIMISM_URL || 'https://sepolia.optimism.io',
      chainId: 11155420,
      accounts,
    },
  }
};

export default config;
