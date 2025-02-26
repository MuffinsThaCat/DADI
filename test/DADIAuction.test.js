const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("DADIAuction", function () {
  let DADIAuction;
  let dadiAuction;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  let currentTime;

  beforeEach(async function () {
    DADIAuction = await ethers.getContractFactory("DADIAuction");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    dadiAuction = await DADIAuction.deploy();
    await dadiAuction.deployed();
    
    // Set current time for consistent testing
    currentTime = (await ethers.provider.getBlock("latest")).timestamp;
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await dadiAuction.owner()).to.equal(owner.address);
    });

    it("Should start in unpaused state", async function () {
      expect(await dadiAuction.paused()).to.equal(false);
    });
  });

  describe("Auctions", function () {
    let deviceId;
    let startTime;
    let duration;
    let minBid;

    beforeEach(async function () {
      deviceId = ethers.utils.id("device1");
      startTime = currentTime + 3600; // 1 hour from now
      duration = 3600; // 1 hour
      minBid = ethers.utils.parseEther("0.1");
    });

    describe("Creation", function () {
      it("Should create an auction", async function () {
        await expect(dadiAuction.createAuction(deviceId, startTime, duration, minBid))
          .to.emit(dadiAuction, "AuctionCreated")
          .withArgs(deviceId, owner.address, startTime, startTime + duration, minBid);

        const auction = await dadiAuction.getAuction(deviceId);
        expect(auction.deviceOwner).to.equal(owner.address);
        expect(auction.startTime).to.equal(startTime);
        expect(auction.endTime).to.equal(startTime + duration);
        expect(auction.minBid).to.equal(minBid);
        expect(auction.active).to.equal(true);
      });

      it("Should not allow creating auction with past start time", async function () {
        const pastTime = currentTime - 3600;
        await expect(
          dadiAuction.createAuction(deviceId, pastTime, duration, minBid)
        ).to.be.revertedWith("Start time must be in the future");
      });

      it("Should not allow creating auction with zero duration", async function () {
        await expect(
          dadiAuction.createAuction(deviceId, startTime, 0, minBid)
        ).to.be.revertedWith("Duration must be positive");
      });

      it("Should not allow creating auction with zero minimum bid", async function () {
        await expect(
          dadiAuction.createAuction(deviceId, startTime, duration, 0)
        ).to.be.revertedWith("Minimum bid must be positive");
      });
    });

    describe("Bidding", function () {
      beforeEach(async function () {
        await dadiAuction.createAuction(deviceId, startTime, duration, minBid);
        // Move time to start of auction
        await time.increaseTo(startTime);
      });

      it("Should place a bid", async function () {
        const bidAmount = ethers.utils.parseEther("0.2");
        await expect(dadiAuction.connect(addr1).placeBid(deviceId, { value: bidAmount }))
          .to.emit(dadiAuction, "BidPlaced")
          .withArgs(deviceId, addr1.address, bidAmount);

        const auction = await dadiAuction.getAuction(deviceId);
        expect(auction.highestBidder).to.equal(addr1.address);
        expect(auction.highestBid).to.equal(bidAmount);
      });

      it("Should not allow bids lower than minimum bid", async function () {
        const lowBid = ethers.utils.parseEther("0.05");
        await expect(
          dadiAuction.connect(addr1).placeBid(deviceId, { value: lowBid })
        ).to.be.revertedWith("Bid too low");
      });

      it("Should not allow bids lower than current highest bid", async function () {
        const firstBid = ethers.utils.parseEther("0.2");
        await dadiAuction.connect(addr1).placeBid(deviceId, { value: firstBid });

        const lowerBid = ethers.utils.parseEther("0.15");
        await expect(
          dadiAuction.connect(addr2).placeBid(deviceId, { value: lowerBid })
        ).to.be.revertedWith("Bid too low");
      });

      it("Should refund previous bidder when outbid", async function () {
        const firstBid = ethers.utils.parseEther("0.2");
        await dadiAuction.connect(addr1).placeBid(deviceId, { value: firstBid });

        const secondBid = ethers.utils.parseEther("0.3");
        const addr1BalanceBefore = await addr1.getBalance();
        await dadiAuction.connect(addr2).placeBid(deviceId, { value: secondBid });
        const addr1BalanceAfter = await addr1.getBalance();

        expect(addr1BalanceAfter.sub(addr1BalanceBefore)).to.equal(firstBid);
      });

      it("Should not allow bids after auction end", async function () {
        await time.increaseTo(startTime + duration + 1);
        const bidAmount = ethers.utils.parseEther("0.2");
        await expect(
          dadiAuction.connect(addr1).placeBid(deviceId, { value: bidAmount })
        ).to.be.revertedWith("Bidding period has ended");
      });

      it("Should not allow bids before auction start", async function () {
        // Create a new auction that starts later
        const laterStartTime = startTime + 3600;
        const deviceId2 = ethers.utils.id("device2");
        await dadiAuction.createAuction(deviceId2, laterStartTime, duration, minBid);
        
        const bidAmount = ethers.utils.parseEther("0.2");
        await expect(
          dadiAuction.connect(addr1).placeBid(deviceId2, { value: bidAmount })
        ).to.be.revertedWith("Auction has not started");
      });
    });

    describe("Control Transfer", function () {
      beforeEach(async function () {
        await dadiAuction.createAuction(deviceId, startTime, duration, minBid);
        await time.increaseTo(startTime);
        const bidAmount = ethers.utils.parseEther("0.2");
        await dadiAuction.connect(addr1).placeBid(deviceId, { value: bidAmount });
      });

      it("Should transfer control to highest bidder after auction ends", async function () {
        await time.increaseTo(startTime + duration + 1);
        await expect(dadiAuction.finalizeAuction(deviceId))
          .to.emit(dadiAuction, "AuctionEnded")
          .withArgs(deviceId, addr1.address, ethers.utils.parseEther("0.2"))
          .to.emit(dadiAuction, "ControlTransferred")
          .withArgs(deviceId, addr1.address, startTime, startTime + duration);

        const auction = await dadiAuction.getAuction(deviceId);
        expect(auction.active).to.equal(false);
        expect(await dadiAuction.hasControl(deviceId, addr1.address)).to.equal(true);
      });

      it("Should not allow finalizing auction before end time", async function () {
        await expect(dadiAuction.finalizeAuction(deviceId))
          .to.be.revertedWith("Auction has not ended");
      });
    });

    describe("Multiple Auctions", function () {
      it("Should handle multiple active auctions", async function () {
        const deviceId2 = ethers.utils.id("device2");
        await dadiAuction.createAuction(deviceId, startTime, duration, minBid);
        await dadiAuction.createAuction(deviceId2, startTime, duration, minBid);

        await time.increaseTo(startTime);

        const bid1 = ethers.utils.parseEther("0.2");
        const bid2 = ethers.utils.parseEther("0.3");

        await dadiAuction.connect(addr1).placeBid(deviceId, { value: bid1 });
        await dadiAuction.connect(addr2).placeBid(deviceId2, { value: bid2 });

        const auction1 = await dadiAuction.getAuction(deviceId);
        const auction2 = await dadiAuction.getAuction(deviceId2);

        expect(auction1.highestBidder).to.equal(addr1.address);
        expect(auction2.highestBidder).to.equal(addr2.address);
      });
    });
  });

  describe("Pausable", function () {
    let deviceId;
    let startTime;
    let duration;
    let minBid;

    beforeEach(async function () {
      deviceId = ethers.utils.id("device1");
      startTime = currentTime + 3600;
      duration = 3600;
      minBid = ethers.utils.parseEther("0.1");
    });

    it("Should not allow creating auctions when paused", async function () {
      await dadiAuction.pause();
      await expect(
        dadiAuction.createAuction(deviceId, startTime, duration, minBid)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should not allow bidding when paused", async function () {
      await dadiAuction.createAuction(deviceId, startTime, duration, minBid);
      await time.increaseTo(startTime);
      await dadiAuction.pause();
      
      await expect(
        dadiAuction.connect(addr1).placeBid(deviceId, { value: minBid })
      ).to.be.revertedWith("Pausable: paused");
    });
  });
});
