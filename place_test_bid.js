const { ethers } = require("hardhat");

async function main() {
  console.log("Placing a test bid on an auction...");
  
  // Get the contract
  const contractAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  const DADIAuction = await ethers.getContractFactory("DADIAuction");
  const contract = await DADIAuction.attach(contractAddress);
  
  // Get the accounts
  const [deployer, bidder] = await ethers.getSigners();
  console.log(`Using bidder account: ${bidder.address}`);
  
  // Use the device ID from our successful auction
  const deviceId = ethers.utils.formatBytes32String("device_1740724898");
  
  try {
    console.log(`Checking if auction exists for device: ${ethers.utils.parseBytes32String(deviceId)}`);
    
    // Get auction details
    const auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction found:");
    console.log(`- Owner: ${auctionInfo[0]}`);
    console.log(`- Start Time: ${new Date(auctionInfo[1].toNumber() * 1000).toLocaleString()}`);
    console.log(`- End Time: ${new Date(auctionInfo[2].toNumber() * 1000).toLocaleString()}`);
    console.log(`- Minimum Bid: ${ethers.utils.formatEther(auctionInfo[3])} ETH`);
    console.log(`- Current Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Current Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    console.log(`- Active: ${auctionInfo[6]}`);
    
    // Get current blockchain time
    const latestBlock = await ethers.provider.getBlock("latest");
    const currentTime = latestBlock.timestamp;
    console.log(`Current blockchain time: ${new Date(currentTime * 1000).toLocaleString()}`);
    
    // Check if we need to fast-forward time to make auction active
    const startTime = auctionInfo[1].toNumber();
    if (currentTime < startTime) {
      const timeToFastForward = startTime - currentTime + 10; // Add 10 seconds buffer
      console.log(`Fast-forwarding time by ${timeToFastForward} seconds to make auction active...`);
      
      // Fast-forward time using hardhat's time manipulation
      await ethers.provider.send("evm_increaseTime", [timeToFastForward]);
      await ethers.provider.send("evm_mine", []);
      
      // Get new time
      const newBlock = await ethers.provider.getBlock("latest");
      console.log(`New blockchain time: ${new Date(newBlock.timestamp * 1000).toLocaleString()}`);
    }
    
    // Calculate bid amount (minimum bid + 0.01 ETH)
    const minBid = auctionInfo[3];
    const bidAmount = minBid.add(ethers.utils.parseEther("0.01"));
    console.log(`Placing bid of ${ethers.utils.formatEther(bidAmount)} ETH`);
    
    // Place bid
    const bidTx = await contract.connect(bidder).placeBid(deviceId, { value: bidAmount });
    console.log(`Bid transaction hash: ${bidTx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    await bidTx.wait();
    console.log("Bid transaction confirmed!");
    
    // Check updated auction details
    const updatedAuctionInfo = await contract.getAuction(deviceId);
    console.log("Updated auction details:");
    console.log(`- Highest Bidder: ${updatedAuctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(updatedAuctionInfo[5])} ETH`);
    
    console.log("Test bid placed successfully!");
  } catch (error) {
    console.error("Error placing test bid:", error);
    
    // If the error is about the auction not existing, try with a different approach
    if (error.message.includes("not exists") || error.message.includes("revert")) {
      console.log("Auction not found or another error occurred. Trying to find active auctions...");
      
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
          
          // Get auction details
          const auctionInfo = await contract.getAuction(recentDeviceId);
          console.log("Auction found:");
          console.log(`- Owner: ${auctionInfo[0]}`);
          console.log(`- Start Time: ${new Date(auctionInfo[1].toNumber() * 1000).toLocaleString()}`);
          console.log(`- End Time: ${new Date(auctionInfo[2].toNumber() * 1000).toLocaleString()}`);
          console.log(`- Minimum Bid: ${ethers.utils.formatEther(auctionInfo[3])} ETH`);
          
          // Get current blockchain time
          const latestBlock = await ethers.provider.getBlock("latest");
          const currentTime = latestBlock.timestamp;
          console.log(`Current blockchain time: ${new Date(currentTime * 1000).toLocaleString()}`);
          
          // Check if we need to fast-forward time to make auction active
          const startTime = auctionInfo[1].toNumber();
          if (currentTime < startTime) {
            const timeToFastForward = startTime - currentTime + 10; // Add 10 seconds buffer
            console.log(`Fast-forwarding time by ${timeToFastForward} seconds to make auction active...`);
            
            // Fast-forward time using hardhat's time manipulation
            await ethers.provider.send("evm_increaseTime", [timeToFastForward]);
            await ethers.provider.send("evm_mine", []);
            
            // Get new time
            const newBlock = await ethers.provider.getBlock("latest");
            console.log(`New blockchain time: ${new Date(newBlock.timestamp * 1000).toLocaleString()}`);
          }
          
          // Calculate bid amount (minimum bid + 0.01 ETH)
          const minBid = auctionInfo[3];
          const bidAmount = minBid.add(ethers.utils.parseEther("0.01"));
          console.log(`Placing bid of ${ethers.utils.formatEther(bidAmount)} ETH`);
          
          // Place bid
          const bidTx = await contract.connect(bidder).placeBid(recentDeviceId, { value: bidAmount });
          console.log(`Bid transaction hash: ${bidTx.hash}`);
          console.log("Waiting for transaction confirmation...");
          
          await bidTx.wait();
          console.log("Bid transaction confirmed!");
          
          // Check updated auction details
          const updatedAuctionInfo = await contract.getAuction(recentDeviceId);
          console.log("Updated auction details:");
          console.log(`- Highest Bidder: ${updatedAuctionInfo[4]}`);
          console.log(`- Highest Bid: ${ethers.utils.formatEther(updatedAuctionInfo[5])} ETH`);
          
          console.log("Test bid placed successfully!");
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
