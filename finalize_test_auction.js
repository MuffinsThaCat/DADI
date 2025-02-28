const { ethers } = require("hardhat");

async function main() {
  console.log("Finalizing a test auction...");
  
  // Get the contract
  const contractAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  const DADIAuction = await ethers.getContractFactory("DADIAuction");
  const contract = await DADIAuction.attach(contractAddress);
  
  // Get the accounts
  const [deployer, bidder] = await ethers.getSigners();
  console.log(`Using deployer account: ${deployer.address}`);
  
  // Use the device ID from our successful auction
  const deviceId = ethers.utils.formatBytes32String("device_1740724898");
  console.log(`Using device ID: ${ethers.utils.parseBytes32String(deviceId)}`);
  
  try {
    // Get auction details
    const auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details:");
    console.log(`- Owner: ${auctionInfo[0]}`);
    console.log(`- Start Time: ${new Date(auctionInfo[1].toNumber() * 1000).toLocaleString()}`);
    console.log(`- End Time: ${new Date(auctionInfo[2].toNumber() * 1000).toLocaleString()}`);
    console.log(`- Minimum Bid: ${ethers.utils.formatEther(auctionInfo[3])} ETH`);
    console.log(`- Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    console.log(`- Active: ${auctionInfo[6]}`);
    
    // Check if the auction is still active
    if (!auctionInfo[6]) {
      console.log("Auction is already finalized.");
      return;
    }
    
    // Get current blockchain time
    const latestBlock = await ethers.provider.getBlock("latest");
    const currentBlockchainTime = latestBlock.timestamp;
    console.log(`Current blockchain time: ${new Date(currentBlockchainTime * 1000).toLocaleString()}`);
    
    // Check if the auction end time has passed
    const endTime = auctionInfo[2].toNumber();
    
    if (currentBlockchainTime < endTime) {
      console.log(`Auction end time (${new Date(endTime * 1000).toLocaleString()}) has not yet passed.`);
      
      // Fast forward time in Hardhat network
      const timeToFastForward = endTime - currentBlockchainTime + 60; // Add 60 seconds buffer
      console.log(`Fast-forwarding time by ${timeToFastForward} seconds...`);
      
      await ethers.provider.send("evm_increaseTime", [timeToFastForward]);
      await ethers.provider.send("evm_mine", []);
      
      // Get new blockchain time
      const newBlock = await ethers.provider.getBlock("latest");
      console.log(`New blockchain time: ${new Date(newBlock.timestamp * 1000).toLocaleString()}`);
    }
    
    // Finalize the auction
    console.log("Finalizing auction...");
    const tx = await contract.finalizeAuction(deviceId);
    console.log(`Transaction hash: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    await tx.wait();
    console.log("Transaction confirmed!");
    
    // Check updated auction details
    const updatedAuctionInfo = await contract.getAuction(deviceId);
    console.log("Updated auction details:");
    console.log(`- Active: ${updatedAuctionInfo[6]}`);
    
    if (!updatedAuctionInfo[6]) {
      console.log("Auction finalized successfully!");
      
      // Check balances
      const ownerBalance = await ethers.provider.getBalance(auctionInfo[0]);
      const bidderBalance = await ethers.provider.getBalance(auctionInfo[4]);
      
      console.log(`Owner balance: ${ethers.utils.formatEther(ownerBalance)} ETH`);
      console.log(`Highest bidder balance: ${ethers.utils.formatEther(bidderBalance)} ETH`);
    } else {
      console.log("Auction is still active after finalization attempt.");
    }
  } catch (error) {
    console.error("Error finalizing auction:", error);
    
    // If the error is about the auction not existing, try with the fallback approach
    if (error.message.includes("not exists") || error.message.includes("revert")) {
      console.log("Auction not found with the specified device ID. Trying to find active auctions...");
      
      try {
        // List all events to find an active auction
        console.log("Searching for active auctions...");
        const filter = contract.filters.AuctionCreated();
        const events = await contract.queryFilter(filter);
        
        if (events.length > 0) {
          // Use the most recent auction
          const mostRecentEvent = events[events.length - 1];
          const recentDeviceId = mostRecentEvent.args.deviceId;
          
          console.log(`Found auction with device ID: ${ethers.utils.parseBytes32String(recentDeviceId)}`);
          
          // Get auction details and continue with the same logic...
          // (This is a fallback, so we'll keep it simple)
          console.log("Please run the script again with the correct device ID.");
        } else {
          console.log("No auctions found. Please create an auction first using create_test_auction.js");
        }
      } catch (secondError) {
        console.error("Error in fallback auction search:", secondError);
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
