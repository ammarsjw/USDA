const { ethers, upgrades } = require("hardhat");

async function main() {
  const PioneerNFT = await ethers.getContractFactory(
    "PioneerNFT"
  );
  console.log("Upgrading PioneerNFT...");
  await upgrades.upgradeProxy(
    "0x79E79Fb59E612AFd801D5D2d74F67Ff6F10d9f14", // old address
    PioneerNFT
  );
  console.log("Upgraded Successfully");
}

main();