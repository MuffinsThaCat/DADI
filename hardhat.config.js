require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

// Environment variables with fallbacks
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "https://sepolia.infura.io/v3/your-api-key";
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || "https://mainnet.infura.io/v3/your-api-key";
const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL || "https://polygon-mainnet.infura.io/v3/your-api-key";
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL || "https://polygon-mumbai.infura.io/v3/your-api-key";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337,
      mining: {
        auto: true,
        interval: 0
      },
      // Enable CORS for local development with more explicit settings
      jsonRpcServer: {
        host: "127.0.0.1",
        port: 8087,
        cors: {
          origin: "*",
          methods: ["GET", "POST"],
          credentials: false
        },
        rpcOnly: true
      }
    },
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8087",
      timeout: 60000, // Increase timeout for local development
    },
    // Updated from Goerli to Sepolia
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      verify: {
        etherscan: {
          apiKey: ETHERSCAN_API_KEY
        }
      }
    },
    // Additional networks for more deployment options
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 1,
      verify: {
        etherscan: {
          apiKey: ETHERSCAN_API_KEY
        }
      }
    },
    polygon: {
      url: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 137,
      verify: {
        etherscan: {
          apiKey: ETHERSCAN_API_KEY
        }
      }
    },
    mumbai: {
      url: MUMBAI_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 80001,
      verify: {
        etherscan: {
          apiKey: ETHERSCAN_API_KEY
        }
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  mocha: {
    timeout: 60000 // Increase timeout for tests
  }
};
