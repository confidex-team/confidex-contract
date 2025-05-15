const hre = require("hardhat")

async function main() {
  const [deployer] = await hre.viem.getWalletClients()
  const confiToken = await hre.viem.deployContract("ConfiToken", [
    1000000000000000000000000, // initialSupply (1 million tokens)
    "ConfiToken", // name
    "CFT", // symbol
  ])

  console.log("ConfiToken deployed to:", confiToken.address)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
