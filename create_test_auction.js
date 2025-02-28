const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Creating a test auction on the blockchain...");
  
  // Get the contract
  const contractAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  const DADIAuction = await ethers.getContractFactory("DADIAuction");
  const contract = await DADIAuction.attach(contractAddress);
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get current blockchain time
  const latestBlock = await ethers.provider.getBlock("latest");
  const currentBlockchainTime = latestBlock.timestamp;
  console.log(`Current blockchain time: ${new Date(currentBlockchainTime * 1000).toLocaleString()}`);
  
  // Generate a unique device ID (using timestamp)
  const timestamp = Math.floor(Date.now() / 1000);
  
  // Set auction parameters
  const deviceId = ethers.utils.formatBytes32String(`device_${timestamp}`);
  const startTime = currentBlockchainTime + 600; // Start 10 minutes from blockchain time
  const duration = 3600; // 1 hour duration
  const minBid = ethers.utils.parseEther("0.1"); // 0.1 ETH
  
  try {
    console.log(`Creating auction for device: ${ethers.utils.parseBytes32String(deviceId)}`);
    console.log(`Start Time: ${new Date(startTime * 1000).toLocaleString()}`);
    console.log(`Duration: ${duration} seconds (${duration/3600} hours)`);
    console.log(`Minimum Bid: ${ethers.utils.formatEther(minBid)} ETH`);
    
    // Create the auction
    const tx = await contract.createAuction(
      deviceId,
      startTime,
      duration,
      minBid
    );
    
    console.log(`Transaction hash: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    await tx.wait();
    console.log("Transaction confirmed!");
    
    // Verify the auction was created by getting its details
    try {
      const auctionInfo = await contract.getAuction(deviceId);
      console.log("Auction created successfully:");
      console.log(`- Device Owner: ${auctionInfo[0]}`);
      console.log(`- Start Time: ${new Date(auctionInfo[1].toNumber() * 1000).toLocaleString()}`);
      console.log(`- End Time: ${new Date(auctionInfo[2].toNumber() * 1000).toLocaleString()}`);
      console.log(`- Minimum Bid: ${ethers.utils.formatEther(auctionInfo[3])} ETH`);
      console.log(`- Highest Bidder: ${auctionInfo[4] === ethers.constants.AddressZero ? "None" : auctionInfo[4]}`);
      console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
      console.log(`- Active: ${auctionInfo[6]}`);
    } catch (error) {
      console.error("Error retrieving auction details:", error);
    }
    
    console.log("Test auction created successfully!");
  } catch (error) {
    console.error("Error creating test auction:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
