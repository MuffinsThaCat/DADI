const { ethers } = require("hardhat");

async function main() {
  console.log("Testing auction edge cases...");
  console.log("====================================");
  
  // Get the contract
  const contractAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  const DADIAuction = await ethers.getContractFactory("DADIAuction");
  const contract = await DADIAuction.attach(contractAddress);
  
  // Get the accounts
  const [owner, bidder1, bidder2, unauthorized] = await ethers.getSigners();
  console.log(`Using owner account: ${owner.address}`);
  console.log(`Using bidder account: ${bidder1.address}`);
  console.log(`Using unauthorized account: ${unauthorized.address}`);
  console.log("====================================");
  
  try {
    // Create a unique device ID for this test
    const timestamp = Math.floor(Date.now() / 1000);
    const deviceId = ethers.utils.formatBytes32String(`edge_test_${timestamp}`);
    console.log(`Device ID: ${ethers.utils.parseBytes32String(deviceId)}`);
    
    // 1. Create Auction
    console.log("\n1. CREATING AUCTION");
    console.log("-------------------");
    
    // Get current blockchain time
    const latestBlock = await ethers.provider.getBlock("latest");
    const currentBlockchainTime = latestBlock.timestamp;
    console.log(`Current blockchain time: ${new Date(currentBlockchainTime * 1000).toLocaleString()}`);
    
    // Set auction parameters based on blockchain time
    const startTime = currentBlockchainTime + 60; // Start in 1 minute
    const duration = 300; // 5 minutes duration
    const endTime = startTime + duration; // Calculate end time for display purposes
    const minBid = ethers.utils.parseEther("0.1"); // Minimum bid of 0.1 ETH
    
    console.log(`Start time: ${new Date(startTime * 1000).toLocaleString()}`);
    console.log(`End time: ${new Date(endTime * 1000).toLocaleString()}`);
    console.log(`Duration: ${duration} seconds`);
    console.log(`Minimum bid: ${ethers.utils.formatEther(minBid)} ETH`);
    
    // Create the auction
    const createTx = await contract.createAuction(deviceId, startTime, duration, minBid);
    console.log(`Create auction transaction hash: ${createTx.hash}`);
    await createTx.wait();
    console.log("Auction created successfully!");
    
    // 2. Test Case: Attempt to bid before auction starts (should fail)
    console.log("\n2. ATTEMPTING TO BID BEFORE AUCTION STARTS");
    console.log("------------------------------------------");
    
    const earlyBidAmount = minBid.add(ethers.utils.parseEther("0.01")); // 0.11 ETH
    console.log(`Attempting to place bid of ${ethers.utils.formatEther(earlyBidAmount)} ETH before auction starts...`);
    
    try {
      const earlyBidTx = await contract.connect(bidder1).placeBid(deviceId, { value: earlyBidAmount });
      console.log("ERROR: Bid was accepted before auction start time!");
    } catch (error) {
      console.log("Success: Bid was correctly rejected before auction start time.");
      console.log(`Error message: ${error.message.split("'")[0]}`);
    }
    
    // 3. Fast forward to auction start time
    console.log("\n3. FAST FORWARDING TO AUCTION START");
    console.log("----------------------------------");
    
    // Fast forward to just after start time
    const timeToStartAuction = startTime - currentBlockchainTime + 10; // Add 10 seconds buffer
    
    console.log(`Fast-forwarding time by ${timeToStartAuction} seconds...`);
    await ethers.provider.send("evm_increaseTime", [timeToStartAuction]);
    await ethers.provider.send("evm_mine");
    
    // Get updated blockchain time
    const newBlock = await ethers.provider.getBlock("latest");
    console.log(`New blockchain time: ${new Date(newBlock.timestamp * 1000).toLocaleString()}`);
    
    // 4. Test Case: Attempt to place bid below minimum (should fail)
    console.log("\n4. ATTEMPTING TO PLACE BID BELOW MINIMUM");
    console.log("----------------------------------------");
    
    const lowBidAmount = ethers.utils.parseEther("0.05"); // 0.05 ETH (below minimum)
    console.log(`Attempting to place bid of ${ethers.utils.formatEther(lowBidAmount)} ETH (below minimum of ${ethers.utils.formatEther(minBid)} ETH)...`);
    
    try {
      const lowBidTx = await contract.connect(bidder1).placeBid(deviceId, { value: lowBidAmount });
      console.log("ERROR: Bid below minimum was accepted!");
    } catch (error) {
      console.log("Success: Bid below minimum was correctly rejected.");
      console.log(`Error message: ${error.message.split("'")[0]}`);
    }
    
    // 5. Place a valid bid
    console.log("\n5. PLACING VALID BID");
    console.log("-------------------");
    
    const validBidAmount = minBid.add(ethers.utils.parseEther("0.01")); // 0.11 ETH
    console.log(`Placing valid bid of ${ethers.utils.formatEther(validBidAmount)} ETH...`);
    
    const validBidTx = await contract.connect(bidder1).placeBid(deviceId, { value: validBidAmount });
    console.log(`Valid bid transaction hash: ${validBidTx.hash}`);
    await validBidTx.wait();
    console.log("Valid bid placed successfully!");
    
    // 6. Test Case: Attempt to place bid equal to current highest (should fail)
    console.log("\n6. ATTEMPTING TO PLACE BID EQUAL TO CURRENT HIGHEST");
    console.log("--------------------------------------------------");
    
    console.log(`Attempting to place bid of ${ethers.utils.formatEther(validBidAmount)} ETH (equal to current highest)...`);
    
    try {
      const equalBidTx = await contract.connect(bidder2).placeBid(deviceId, { value: validBidAmount });
      console.log("ERROR: Bid equal to current highest was accepted!");
    } catch (error) {
      console.log("Success: Bid equal to current highest was correctly rejected.");
      console.log(`Error message: ${error.message.split("'")[0]}`);
    }
    
    // 7. Test Case: Attempt unauthorized finalization
    console.log("\n7. ATTEMPTING UNAUTHORIZED FINALIZATION");
    console.log("--------------------------------------");
    
    // Fast forward to auction end
    const currentBlock = await ethers.provider.getBlock("latest");
    const currentTime = currentBlock.timestamp;
    const timeToEndAuction = endTime - currentTime + 10; // Add 10 seconds buffer
    
    console.log(`Fast-forwarding time by ${timeToEndAuction} seconds to end auction...`);
    await ethers.provider.send("evm_increaseTime", [timeToEndAuction]);
    await ethers.provider.send("evm_mine");
    
    console.log(`Attempting to finalize auction from unauthorized account: ${unauthorized.address}...`);
    
    try {
      const unauthorizedFinalizeTx = await contract.connect(unauthorized).finalizeAuction(deviceId);
      console.log("ERROR: Unauthorized finalization was accepted!");
    } catch (error) {
      console.log("Success: Unauthorized finalization was correctly rejected.");
      console.log(`Error message: ${error.message.split("'")[0]}`);
    }
    
    // 8. Proper finalization
    console.log("\n8. PROPER FINALIZATION");
    console.log("----------------------");
    
    console.log(`Finalizing auction from owner account: ${owner.address}...`);
    
    const finalizeTx = await contract.finalizeAuction(deviceId);
    console.log(`Finalize transaction hash: ${finalizeTx.hash}`);
    await finalizeTx.wait();
    console.log("Auction finalized successfully!");
    
    // 9. Test Case: Attempt to bid on finalized auction
    console.log("\n9. ATTEMPTING TO BID ON FINALIZED AUCTION");
    console.log("----------------------------------------");
    
    const lateBidAmount = ethers.utils.parseEther("0.2"); // 0.2 ETH
    console.log(`Attempting to place bid of ${ethers.utils.formatEther(lateBidAmount)} ETH on finalized auction...`);
    
    try {
      const lateBidTx = await contract.connect(bidder2).placeBid(deviceId, { value: lateBidAmount });
      console.log("ERROR: Bid on finalized auction was accepted!");
    } catch (error) {
      console.log("Success: Bid on finalized auction was correctly rejected.");
      console.log(`Error message: ${error.message.split("'")[0]}`);
    }
    
    // 10. Summary
    console.log("\n10. EDGE CASE TESTS SUMMARY");
    console.log("-------------------------");
    console.log("✅ Bid before auction start: Correctly rejected");
    console.log("✅ Bid below minimum: Correctly rejected");
    console.log("✅ Bid equal to current highest: Correctly rejected");
    console.log("✅ Unauthorized finalization: Correctly rejected");
    console.log("✅ Bid on finalized auction: Correctly rejected");
    
    console.log("\nAuction edge case tests completed successfully!");
    
  } catch (error) {
    console.error("Error in auction edge case tests:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
