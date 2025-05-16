const hre = require("hardhat")

async function main() {
  const [account] = await hre.viem.getWalletClients()
  const trustedSigner = "0x39e5A008A0f182398d76c422E551a1348675Dc1b"
  const confidex = await hre.viem.deployContract("Confidex", [
    trustedSigner, // trustedSigner address
  ])

  console.log("Confidex deployed to:", confidex.address)
  console.log("Owner address:", account.account.address)
  console.log("Trusted signer address:", trustedSigner)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
