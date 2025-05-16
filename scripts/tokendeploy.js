const hre = require("hardhat")

async function main() {
  const [account] = await hre.viem.getWalletClients()
  const initialSupply = 1000000000000000000000000
  const name = "COMFY"
  const symbol = "cCMF"
  const confiToken = await hre.viem.deployContract("ConfidentialERC20", [
    name, // name
    symbol, // symbol
  ])

  console.log("\n===========================================")
  console.log("Confidential Token Deployment Successful ✅")
  console.log("===========================================")
  console.log("📝 Contract Name:", name)
  console.log("🏠 Contract Address:", confiToken.address)
  console.log("💰 Initial Supply:", initialSupply)
  console.log("🔤 Token Symbol:", symbol)
  console.log("===========================================\n")
  console.log("Owner address:", account.account.address)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
