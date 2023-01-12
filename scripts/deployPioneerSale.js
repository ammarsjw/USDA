const { ethers } = require("hardhat");

const { network, run } = require("hardhat");

const hrdht = require("hardhat");

async function verify(address, constructorArguments) {
  console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
  await hrdht.run("verify:verify", {
    address,
    constructorArguments
  });
}


async function main() {

  const fundsWallet = "0xFa4bef5dda4641559917cF00824e98D2be5916b9";
  const marketing = "0x0Cc45a16e5A2FEC8c0D925F2e4eA14Bf0530C22F";
  const merkleRoot = "0x609f642d28e8bd468eacd0ca80ff5ffa2e3a66b896dc947c95e6f592f14b0f09"
  const tomi = "0x3a06cF44DFC0010350F4F6F339d01a6f258AD9D0";
  const usdt = "0x2c05EA5C7abb21510840428EBDFCe047511E7ba1";
  const usdc = "0xb962006C2793820e7c3c026667DD57f094Dbf30b";
  const pioneer = "0x70f5398F6e510DfBdbFfa18789AcfB7F5B84Deed";
  const priceFeed = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e";

  const SalePioneer_ = await ethers.getContractFactory("SalePioneer");
  const SalePioneer = await SalePioneer_.deploy(
    60,
    900,
    fundsWallet,
    marketing,
    merkleRoot,
    tomi,
    usdt,
    usdc,
    pioneer,
    priceFeed);
  await SalePioneer.deployed();

  console.log(`SalePioneer deployed to ${SalePioneer.address}`);


  await new Promise(resolve => setTimeout(resolve, 20000));
  verify(SalePioneer.address, [60, 900, fundsWallet, marketing, merkleRoot, tomi, usdt, usdc, pioneer, priceFeed])
  // verify('0x72e4309d0E2ea75fA829c5c6127eE59aECd9B519', [60, 900, fundsWallet, marketing, merkleRoot, tomi, usdt, usdc, pioneer, priceFeed])
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
