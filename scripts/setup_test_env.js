const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Setting up test environment...");

  // Get test accounts
  const accounts = await hre.ethers.getSigners();
  const [owner, bidder1, bidder2] = accounts;

  console.log("\nTest Accounts:");
  console.log(`Owner: ${owner.address}`);
  console.log(`Bidder 1: ${bidder1.address}`);
  console.log(`Bidder 2: ${bidder2.address}`);

  // Deploy the contract
  console.log("\nDeploying DADIAuction contract...");
  const DADIAuction = await hre.ethers.getContractFactory("DADIAuction");
  const dadiAuction = await DADIAuction.deploy();
  await dadiAuction.deployed();
  console.log(`DADIAuction deployed to: ${dadiAuction.address}`);

  // Create test auctions
  console.log("\nCreating test auctions...");
  
  // Current timestamp
  const now = Math.floor(Date.now() / 1000);
  
  // Create auctions with different start times
  const auctions = [
    {
      deviceId: hre.ethers.utils.id("device_1"),
      startTime: now + 300, // Starts in 5 minutes
      duration: 3600, // 1 hour
      minBid: hre.ethers.utils.parseEther("0.1"),
    },
    {
      deviceId: hre.ethers.utils.id("device_2"),
      startTime: now + 60, // Starts in 1 minute
      duration: 1800, // 30 minutes
      minBid: hre.ethers.utils.parseEther("0.05"),
    },
  ];

  for (const auction of auctions) {
    await dadiAuction.createAuction(
      auction.deviceId,
      auction.startTime,
      auction.duration,
      auction.minBid
    );
    console.log(`Created auction for device: ${auction.deviceId}`);
  }

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    contractAddress: dadiAuction.address,
    owner: owner.address,
    testAccounts: {
      bidder1: bidder1.address,
      bidder2: bidder2.address,
    },
    testAuctions: auctions,
  };

  const deploymentPath = path.join(__dirname, '..', 'deployment.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\nDeployment info saved to: ${deploymentPath}`);

  // Print test instructions
  console.log("\nTest Environment Setup Complete!");
  console.log("\nTo test the app:");
  console.log("1. Import these accounts to MetaMask:");
  console.log("   Owner:    0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
  console.log("   Bidder 1: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC");
  console.log("   Bidder 2: 0x90F79bf6EB2c4f870365E785982E1f101E93b906");
  console.log("\n2. Each account has 10000 ETH for testing");
  console.log("\n3. Contract address for Web3Service:");
  console.log(`   ${dadiAuction.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
