const hre = require("hardhat")

async function main() {
  const [deployer] = await hre.viem.getWalletClients()
  const confidex = await hre.viem.deployContract("Confidex", [
    "0x92b9baa72387fb845d8fe88d2a14113f9cb2c4e7", // trustedSigner address
  ])

  console.log("Confidex deployed to:", confidex.address)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
