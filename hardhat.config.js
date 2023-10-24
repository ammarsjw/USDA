require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
    solidity: {
        compilers: [
            {
                version: '0.8.17',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        goerli: {
            url: process.env.URL_GOERLI,
            accounts: [process.env.PRIVATE_KEY_GOERLI],
        },
        mainnet: {
            url: process.env.URL_MAINNET,
            accounts: [process.env.PRIVATE_KEY_MAINNET],
        },
    },
    etherscan: {
        apiKey: process.env.BLOCK_EXPLORER_API_KEY_ETHEREUM
    },
};
