const { ethers } = require("hardhat");

const { network, run } = require("hardhat");

async function verify(address, constructorArguments) {
  console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
  await run("verify:verify", {
    address,
    constructorArguments
  })
}

// Deploy, verify and then change the below address for IterableMapping
async function main() {
  let USDA = await ethers.getContractFactory("USDA", {
    libraries: {
      IterableMapping: "0x0a0a91B19AC5fFc80d5973510445541660963734",
    }
  });

  const contract = await upgrades.deployProxy(USDA, [], {
    unsafeAllowLinkedLibraries: true,
    initializer: "initialize",
    kind: "transparent"
  });

  await contract.deployed();

  console.log("USDA Proxy deployed to:", contract.address);

  await new Promise(resolve => setTimeout(resolve, 20000));

  verify(contract.address, [])
}

main();