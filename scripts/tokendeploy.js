const hre = require("hardhat")

async function main() {
  const [account] = await hre.viem.getWalletClients()
  const initialSupply = 1000000000000000000000000
  const name = "ConfiToken"
  const symbol = "CFT"
  const confiToken = await hre.viem.deployContract("ConfiToken", [
    initialSupply, // initialSupply (1 million tokens)
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
