const hre = require("hardhat")

async function main() {
  const [deployer] = await hre.viem.getWalletClients()
  const confidex = await hre.viem.deployContract("Confidex", [
    "0x39e5A008A0f182398d76c422E551a1348675Dc1b", // trustedSigner address
  ])

  console.log("Confidex deployed to:", confidex.address)
  console.log("Deployer address:", deployer.address)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
