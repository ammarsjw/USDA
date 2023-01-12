const hre = require("hardhat");
const fs = require('fs')
const envfile = require('envfile')
const { network, run } = require("hardhat")

const ethers = hre.ethers;
const utils = ethers.utils;

async function verify(address, constructorArguments) {
    console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
    await run("verify:verify", {
        address,
        constructorArguments
    })
}

async function main() {

    const tomiAddress  = ""
    const pioneerAddress  = ""
    const vestingContract  = ""
    const saleAddress  = ""


    console.log("done");



}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })