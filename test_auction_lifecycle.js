const { ethers } = require("hardhat");

async function main() {
  console.log("Testing complete auction lifecycle...");
  console.log("====================================");
  
  // Get the contract
  const contractAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  const DADIAuction = await ethers.getContractFactory("DADIAuction");
  const contract = await DADIAuction.attach(contractAddress);
  
  // Get the accounts
  const [owner, bidder1, bidder2, bidder3] = await ethers.getSigners();
  console.log(`Using owner account: ${owner.address}`);
  console.log(`Using bidder1 account: ${bidder1.address}`);
  console.log(`Using bidder2 account: ${bidder2.address}`);
  console.log(`Using bidder3 account: ${bidder3.address}`);
  console.log("====================================");
  
  try {
    // Create a unique device ID for this test
    const timestamp = Math.floor(Date.now() / 1000);
    const deviceId = ethers.utils.formatBytes32String(`test_device_${timestamp}`);
    console.log(`Device ID: ${ethers.utils.parseBytes32String(deviceId)}`);
    
    // 1. Create Auction
    console.log("\n1. CREATING AUCTION");
    console.log("-------------------");
    
    // Get current blockchain time
    const latestBlock = await ethers.provider.getBlock("latest");
    const currentBlockchainTime = latestBlock.timestamp;
    console.log(`Current blockchain time: ${new Date(currentBlockchainTime * 1000).toLocaleString()}`);
    
    // Set auction parameters based on blockchain time
    const startTime = currentBlockchainTime + 600; // Start in 10 minutes
    const duration = 600; // 10 minutes duration
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
    
    // Get auction details
    let auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details:");
    console.log(`- Owner: ${auctionInfo[0]}`);
    console.log(`- Start Time: ${new Date(auctionInfo[1].toNumber() * 1000).toLocaleString()}`);
    console.log(`- End Time: ${new Date(auctionInfo[2].toNumber() * 1000).toLocaleString()}`);
    console.log(`- Minimum Bid: ${ethers.utils.formatEther(auctionInfo[3])} ETH`);
    console.log(`- Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    console.log(`- Active: ${auctionInfo[6]}`);
    
    // 2. Fast forward to auction start time
    console.log("\n2. FAST FORWARDING TO AUCTION START");
    console.log("----------------------------------");
    
    // Fast forward to just after start time
    const timeToStartAuction = startTime - currentBlockchainTime + 10; // Add 10 seconds buffer
    
    console.log(`Fast-forwarding time by ${timeToStartAuction} seconds...`);
    await ethers.provider.send("evm_increaseTime", [timeToStartAuction]);
    await ethers.provider.send("evm_mine");
    
    // Get updated blockchain time
    const newBlock = await ethers.provider.getBlock("latest");
    console.log(`New blockchain time: ${new Date(newBlock.timestamp * 1000).toLocaleString()}`);
    console.log("Time fast-forwarded to after auction start!");
    
    // 3. Place bids
    console.log("\n3. PLACING BIDS");
    console.log("---------------");
    
    // Bidder 1 places bid
    const bid1Amount = minBid.add(ethers.utils.parseEther("0.01")); // 0.11 ETH
    console.log(`Bidder 1 (${bidder1.address}) placing bid of ${ethers.utils.formatEther(bid1Amount)} ETH`);
    
    const bid1Tx = await contract.connect(bidder1).placeBid(deviceId, { value: bid1Amount });
    console.log(`Bid 1 transaction hash: ${bid1Tx.hash}`);
    await bid1Tx.wait();
    console.log("Bid 1 placed successfully!");
    
    // Get updated auction details
    auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details after bid 1:");
    console.log(`- Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    
    // Bidder 2 places higher bid
    const bid2Amount = bid1Amount.add(ethers.utils.parseEther("0.02")); // 0.13 ETH
    console.log(`\nBidder 2 (${bidder2.address}) placing bid of ${ethers.utils.formatEther(bid2Amount)} ETH`);
    
    const bid2Tx = await contract.connect(bidder2).placeBid(deviceId, { value: bid2Amount });
    console.log(`Bid 2 transaction hash: ${bid2Tx.hash}`);
    await bid2Tx.wait();
    console.log("Bid 2 placed successfully!");
    
    // Get updated auction details
    auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details after bid 2:");
    console.log(`- Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    
    // Bidder 3 places highest bid
    const bid3Amount = bid2Amount.add(ethers.utils.parseEther("0.05")); // 0.18 ETH
    console.log(`\nBidder 3 (${bidder3.address}) placing bid of ${ethers.utils.formatEther(bid3Amount)} ETH`);
    
    const bid3Tx = await contract.connect(bidder3).placeBid(deviceId, { value: bid3Amount });
    console.log(`Bid 3 transaction hash: ${bid3Tx.hash}`);
    await bid3Tx.wait();
    console.log("Bid 3 placed successfully!");
    
    // Get updated auction details
    auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details after bid 3:");
    console.log(`- Highest Bidder: ${auctionInfo[4]}`);
    console.log(`- Highest Bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    
    // 4. Fast forward to auction end time
    console.log("\n4. FAST FORWARDING TO AUCTION END");
    console.log("--------------------------------");
    
    // Get current blockchain time again
    const latestBlock2 = await ethers.provider.getBlock("latest");
    const currentBlockchainTime2 = latestBlock2.timestamp;
    
    // Calculate time to end auction
    const timeToEndAuction = endTime - currentBlockchainTime2 + 10; // Add 10 seconds buffer
    
    console.log(`Fast-forwarding time by ${timeToEndAuction} seconds...`);
    await ethers.provider.send("evm_increaseTime", [timeToEndAuction]);
    await ethers.provider.send("evm_mine");
    
    // Get updated blockchain time
    const newBlock2 = await ethers.provider.getBlock("latest");
    console.log(`New blockchain time: ${new Date(newBlock2.timestamp * 1000).toLocaleString()}`);
    console.log("Time fast-forwarded to after auction end!");
    
    // 5. Finalize auction
    console.log("\n5. FINALIZING AUCTION");
    console.log("--------------------");
    
    // Get balances before finalization
    const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
    const bidder3BalanceBefore = await ethers.provider.getBalance(bidder3.address);
    
    console.log(`Owner balance before: ${ethers.utils.formatEther(ownerBalanceBefore)} ETH`);
    console.log(`Highest bidder (Bidder 3) balance before: ${ethers.utils.formatEther(bidder3BalanceBefore)} ETH`);
    
    // Finalize the auction
    const finalizeTx = await contract.finalizeAuction(deviceId);
    console.log(`Finalize transaction hash: ${finalizeTx.hash}`);
    await finalizeTx.wait();
    console.log("Auction finalized successfully!");
    
    // Get updated auction details
    auctionInfo = await contract.getAuction(deviceId);
    console.log("Auction details after finalization:");
    console.log(`- Active: ${auctionInfo[6]}`);
    
    // Get balances after finalization
    const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
    const bidder3BalanceAfter = await ethers.provider.getBalance(bidder3.address);
    
    console.log(`Owner balance after: ${ethers.utils.formatEther(ownerBalanceAfter)} ETH`);
    console.log(`Highest bidder (Bidder 3) balance after: ${ethers.utils.formatEther(bidder3BalanceAfter)} ETH`);
    
    // Calculate balance changes
    const ownerBalanceChange = ownerBalanceAfter.sub(ownerBalanceBefore);
    console.log(`Owner balance change: +${ethers.utils.formatEther(ownerBalanceChange)} ETH`);
    
    // 6. Summary
    console.log("\n6. AUCTION LIFECYCLE SUMMARY");
    console.log("--------------------------");
    console.log(`Device ID: ${ethers.utils.parseBytes32String(deviceId)}`);
    console.log(`Auction owner: ${owner.address}`);
    console.log(`Final highest bidder: ${auctionInfo[4]}`);
    console.log(`Final highest bid: ${ethers.utils.formatEther(auctionInfo[5])} ETH`);
    console.log(`Auction active status: ${auctionInfo[6]}`);
    console.log(`Owner received: ${ethers.utils.formatEther(ownerBalanceChange)} ETH`);
    
    console.log("\nAuction lifecycle test completed successfully!");
    
  } catch (error) {
    console.error("Error in auction lifecycle test:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
