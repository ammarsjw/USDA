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

  const tomiAsProxy = "0x4385328cc4D643Ca98DfEA734360C0F596C83449"
  const tomi1 = "0x9779463B21a7e4ccF390bb0eA6692C4D44A3718d"
  const tomi2 = "0xFa4bef5dda4641559917cF00824e98D2be5916b9"

  const TomiVesting_ = await ethers.getContractFactory("TomiVesting");
  const TomiVesting = await TomiVesting_.deploy(tomi1, tomi2, tomiAsProxy);
  await TomiVesting.deployed();

  console.log(`TomiVesting deployed to ${TomiVesting.address}`);

  await new Promise(resolve => setTimeout(resolve, 10000));
  verify(TomiVesting.address, [tomi1, tomi2, tomiAsProxy]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
