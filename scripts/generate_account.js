const { ethers } = require("hardhat");

async function main() {
  // Generate a new random wallet
  const wallet = ethers.Wallet.createRandom();
  
  console.log("New Account Generated:");
  console.log("Address:", wallet.address);
  console.log("Private Key:", wallet.privateKey);
  console.log("\nTo import this account into MetaMask:");
  console.log("1. Copy this private key (without the 0x prefix):");
  console.log(wallet.privateKey.slice(2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
