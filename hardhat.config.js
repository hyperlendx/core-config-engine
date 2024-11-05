require("dotenv").config()
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  networks: {
    hardhat: {
        // forking: {
        //     url: `https://api.hyperliquid-testnet.xyz/evm`,
        // },
    },
    hyperEvmTestnet: {
        accounts: [process.env.PRIVATE_KEY],
        chainId: 998,
        url: 'https://api.hyperliquid-testnet.xyz/evm'
    }
  },
  etherscan: {
    apiKey: {
        hyperEvmTestnet: 'empty',
    },
    customChains: [
        {
          network: "hyperEvmTestnet",
          chainId: 998,
          urls: {
            apiURL: "https://explorer.hyperlend.finance/api",
            browserURL: "https://explorer.hyperlend.finance"
          }
        }
      ]
  },
};
