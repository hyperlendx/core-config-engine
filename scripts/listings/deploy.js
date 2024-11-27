const { ethers } = require("hardhat");
const path = require('path');

const { verify } = require("../utils/verify")

async function main() {
    const ConfigEngineFactory = await ethers.getContractFactory("ConfigEngineFactory");
    const configEngineFactory = await ConfigEngineFactory.deploy()
    console.log(`configEngineFactory deployed to ${configEngineFactory.target}`);

    await verify(configEngineFactory.target, [])
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});