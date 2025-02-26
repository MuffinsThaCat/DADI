// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DADIAuction
 * @dev Manages time-slot auctions for device control
 */
contract DADIAuction is ReentrancyGuard, Pausable, Ownable {
    // Struct to hold auction details
    struct Auction {
        address deviceOwner;
        uint256 startTime;
        uint256 endTime;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
        bool active;
        mapping(address => uint256) bids;
    }

    // Struct to hold time slot control details
    struct TimeSlot {
        address controller;
        uint256 startTime;
        uint256 endTime;
    }

    // Mapping from device ID to its current auction
    mapping(bytes32 => Auction) public auctions;
    
    // Mapping from device ID to its current controller
    mapping(bytes32 => TimeSlot) public activeControllers;

    // Events
    event AuctionCreated(bytes32 indexed deviceId, address indexed owner, uint256 startTime, uint256 endTime, uint256 minBid);
    event BidPlaced(bytes32 indexed deviceId, address indexed bidder, uint256 amount);
    event AuctionEnded(bytes32 indexed deviceId, address indexed winner, uint256 amount);
    event ControlTransferred(bytes32 indexed deviceId, address indexed controller, uint256 startTime, uint256 endTime);

    // Modifiers
    modifier auctionExists(bytes32 deviceId) {
        require(auctions[deviceId].active, "Auction does not exist");
        _;
    }

    modifier auctionNotExists(bytes32 deviceId) {
        require(!auctions[deviceId].active, "Auction already exists");
        _;
    }

    modifier validAuctionPeriod(bytes32 deviceId) {
        Auction storage auction = auctions[deviceId];
        require(block.timestamp >= auction.startTime, "Auction has not started");
        require(block.timestamp <= auction.endTime, "Auction has ended");
        _;
    }

    /**
     * @dev Create a new auction for a device
     * @param deviceId Unique identifier for the device
     * @param startTime When the control period starts
     * @param duration Duration of control in seconds
     * @param minBid Minimum bid amount in wei
     */
    function createAuction(
        bytes32 deviceId,
        uint256 startTime,
        uint256 duration,
        uint256 minBid
    ) external whenNotPaused auctionNotExists(deviceId) {
        require(startTime > block.timestamp, "Start time must be in the future");
        require(duration > 0, "Duration must be positive");
        require(minBid > 0, "Minimum bid must be positive");

        Auction storage auction = auctions[deviceId];
        auction.deviceOwner = msg.sender;
        auction.startTime = startTime;
        auction.endTime = startTime + duration;
        auction.minBid = minBid;
        auction.active = true;

        emit AuctionCreated(deviceId, msg.sender, startTime, startTime + duration, minBid);
    }

    /**
     * @dev Place a bid on an active auction
     * @param deviceId Device being auctioned
     */
    function placeBid(bytes32 deviceId) external payable whenNotPaused auctionExists(deviceId) nonReentrant {
        Auction storage auction = auctions[deviceId];
        
        // Check if auction is in valid bidding period
        require(block.timestamp >= auction.startTime, "Auction has not started");
        require(block.timestamp <= auction.endTime, "Bidding period has ended");
        
        // Validate bid amount
        if (auction.highestBid > 0) {
            require(msg.value > auction.highestBid, "Bid too low");
        } else {
            require(msg.value >= auction.minBid, "Bid too low");
        }

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            uint256 refund = auction.bids[auction.highestBidder];
            auction.bids[auction.highestBidder] = 0;
            payable(auction.highestBidder).transfer(refund);
        }

        // Record new bid
        auction.bids[msg.sender] = msg.value;
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(deviceId, msg.sender, msg.value);
    }

    /**
     * @dev Finalize an auction and transfer control
     * @param deviceId Device being auctioned
     */
    function finalizeAuction(bytes32 deviceId) external nonReentrant auctionExists(deviceId) {
        Auction storage auction = auctions[deviceId];
        
        require(block.timestamp > auction.endTime, "Auction has not ended");
        require(auction.highestBidder != address(0), "No bids placed");
        require(auction.active, "Auction already finalized");

        // Transfer control
        activeControllers[deviceId] = TimeSlot({
            controller: auction.highestBidder,
            startTime: auction.startTime,
            endTime: auction.endTime
        });

        // Transfer funds to device owner
        payable(auction.deviceOwner).transfer(auction.highestBid);

        // Mark auction as inactive
        auction.active = false;

        emit AuctionEnded(deviceId, auction.highestBidder, auction.highestBid);
        emit ControlTransferred(deviceId, auction.highestBidder, auction.startTime, auction.endTime);
    }

    /**
     * @dev Check if a user has control over a device
     * @param deviceId Device to check
     * @param user User address to check
     * @return bool True if user has control
     */
    function hasControl(bytes32 deviceId, address user) public view returns (bool) {
        TimeSlot storage slot = activeControllers[deviceId];
        return slot.controller == user;
    }

    /**
     * @dev Get auction details
     * @param deviceId Device to check
     * @return deviceOwner Address of device owner
     * @return startTime Start time of the auction
     * @return endTime End time of the auction
     * @return minBid Minimum bid amount
     * @return highestBidder Current highest bidder
     * @return highestBid Current highest bid amount
     * @return active Whether the auction is active
     */
    function getAuction(bytes32 deviceId) external view returns (
        address deviceOwner,
        uint256 startTime,
        uint256 endTime,
        uint256 minBid,
        address highestBidder,
        uint256 highestBid,
        bool active
    ) {
        Auction storage auction = auctions[deviceId];
        return (
            auction.deviceOwner,
            auction.startTime,
            auction.endTime,
            auction.minBid,
            auction.highestBidder,
            auction.highestBid,
            auction.active
        );
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
