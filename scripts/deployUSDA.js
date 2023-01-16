const { ethers } = require("hardhat");

const { network, run } = require("hardhat");

async function verify(address, constructorArguments) {
  console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
  await run("verify:verify", {
    address,
    constructorArguments
  })
}

async function main() {
  const PioneerNFT = await ethers.getContractFactory(
    "USDA"
  );
  console.log("Deploying PioneerNFT...");
  const contract = await upgrades.deployProxy(PioneerNFT, [], {
    initializer: "initialize",
    kind: "transparent",
  });
  await contract.deployed();
  console.log("Pioneer deployed to:", contract.address);

  await new Promise(resolve => setTimeout(resolve, 20000));
  verify(contract.address, [])
}

main();