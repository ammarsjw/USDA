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
  const Tomi = await ethers.getContractFactory(
    "Tomi"
  );
  console.log("Deploying Tomi...");
  const contract = await upgrades.deployProxy(Tomi, [], {
    initializer: "initialize",
    kind: "transparent",
  });
  await contract.deployed();
  console.log("Tomi deployed to:", contract.address);

  await new Promise(resolve => setTimeout(resolve, 20000));
  verify(contract.address, [])
}

main();