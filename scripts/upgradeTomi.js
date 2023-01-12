const { ethers, upgrades } = require("hardhat");

async function main() {
  const Tomi = await ethers.getContractFactory(
    "Tomi"
  );
  console.log("Upgrading Tomi...");
  await upgrades.upgradeProxy(
    "0xC81cBaB47B1e6D6d20d4742721e29f22C5835dcB", // old address
    Tomi
  );
  console.log("Upgraded Successfully");
}

main();