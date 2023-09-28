const { ethers, upgrades } = require("hardhat");

async function main() {
    const oldProxyAddress = "0xC81cBaB47B1e6D6d20d4742721e29f22C5835dcB";
    const iterableMappingAddress = "0x0a0a91B19AC5fFc80d5973510445541660963734";


    let USDA = await ethers.getContractFactory("USDA", {
        libraries: {
            IterableMapping: iterableMappingAddress
        }
    });
    await upgrades.upgradeProxy(oldProxyAddress, USDA);
    console.log("Upgraded Successfully");
}

main();
