import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/auction.dart';

/// A provider that always provides mock auctions for web environments
class MockAuctionProvider extends ChangeNotifier {
  final List<Auction> _auctions = [];
  bool _initialized = false;
  
  MockAuctionProvider() {
    _log('MockAuctionProvider initialized');
    if (!_initialized) {
      _initializeMockAuctions();
    }
  }
  
  /// Get all active auctions
  List<Auction> get auctions => _auctions;
  
  /// Log a message with the MockAuctionProvider prefix
  void _log(String message) {
    developer.log('MockAuctionProvider: $message');
  }
  
  /// Initialize mock auctions
  void _initializeMockAuctions() {
    _log('Initializing mock auctions');
    
    final now = DateTime.now();
    
    // Create a multi-slot test device with 6 slots of 5 minutes each
    final String testDeviceId = 'multi-slot-device-test';
    
    // Create 6 sequential 5-minute slots
    for (int i = 0; i < 6; i++) {
      final slotStartTime = now.add(Duration(minutes: i * 5));
      final slotEndTime = slotStartTime.add(const Duration(minutes: 5));
      
      // Use the DeviceSlotIdentifier format: baseDeviceId::timestamp
      final timestamp = slotStartTime.millisecondsSinceEpoch;
      final slotDeviceId = '$testDeviceId::$timestamp';
      
      // For some slots, set a higher bid to show bidding activity
      final double highestBid = i == 1 ? 0.25 : (i == 3 ? 0.35 : 0.1);
      final String highestBidder = (i == 1 || i == 3) 
          ? '0xBidderWallet9876543210' 
          : '0x0000000000000000000000000000000000000000';
      
      _auctions.add(Auction(
        deviceId: slotDeviceId,
        owner: '0xYourWallet1234567890',
        startTime: slotStartTime,
        endTime: slotEndTime,
        minimumBid: 0.1,
        highestBid: highestBid,
        highestBidder: highestBidder,
        isActive: true,
        isFinalized: false,
      ));
      
      _log('Created multi-slot auction: $slotDeviceId from ${slotStartTime.toString()} to ${slotEndTime.toString()}');
    }
    
    // Create a user auction with multiple 5-minute sessions (using the session- format)
    final String userDeviceId = 'user-device-1';
    
    // Add 6 sequential 5-minute sessions for a user device
    for (int i = 0; i < 6; i++) {
      final sessionStart = now.add(Duration(minutes: i * 5));
      final sessionEnd = sessionStart.add(const Duration(minutes: 5));
      final sessionId = '$userDeviceId-session-$i';
      
      // For the first session, set a higher bid to show bidding activity
      final double highestBid = i == 0 ? 0.25 : 0.1;
      final String highestBidder = i == 0 
          ? '0xYourWallet1234567890' // Simulating the user as highest bidder on first session
          : '0x0000000000000000000000000000000000000000';
      
      _auctions.add(Auction(
        deviceId: sessionId,
        owner: '0xYourWallet1234567890', // Set user as owner
        startTime: sessionStart,
        endTime: sessionEnd,
        minimumBid: 0.1,
        highestBid: highestBid,
        highestBidder: highestBidder,
        isActive: true,
        isFinalized: false,
      ));
      
      _log('Created user session auction: $sessionId from ${sessionStart.toString()} to ${sessionEnd.toString()}');
    }
    
    // Create marketplace auction with multiple 5-minute sessions
    final String marketDeviceId = 'market-device-1';
    
    // Add 6 sequential 5-minute sessions for marketplace
    for (int i = 0; i < 6; i++) {
      final sessionStart = now.add(Duration(minutes: i * 5));
      final sessionEnd = sessionStart.add(const Duration(minutes: 5));
      final sessionId = '$marketDeviceId-session-$i';
      
      // Add some bid activity on marketplace auctions
      final double highestBid = i == 2 ? 0.35 : (i == 4 ? 0.4 : 0.1);
      final String highestBidder = (i == 2 || i == 4)
          ? '0xBidder${i}987654321'
          : '0x0000000000000000000000000000000000000000';
      
      _auctions.add(Auction(
        deviceId: sessionId,
        owner: '0xMarketOwner987654321', // Set market owner
        startTime: sessionStart,
        endTime: sessionEnd,
        minimumBid: 0.1,
        highestBid: highestBid,
        highestBidder: highestBidder,
        isActive: true,
        isFinalized: false,
      ));
      
      _log('Created marketplace session auction: $sessionId from ${sessionStart.toString()} to ${sessionEnd.toString()}');
    }
    
    _log('Mock auction provider initialized with user and marketplace 5-minute sessions');
    _initialized = true;
    notifyListeners();
  }
  
  /// Place a bid on an auction
  Future<bool> placeBid(String deviceId, double amount) async {
    _log('Placing mock bid for device: $deviceId, amount: $amount');
    
    final auctionIndex = _auctions.indexWhere((a) => a.deviceId == deviceId);
    if (auctionIndex == -1) {
      _log('Auction not found for device: $deviceId');
      return false;
    }
    
    final auction = _auctions[auctionIndex];
    
    if (auction.endTime.isBefore(DateTime.now())) {
      _log('Auction has ended');
      return false;
    }
    
    if (amount <= auction.highestBid) {
      _log('Bid amount is too low');
      return false;
    }
    
    // Update the auction with the new bid
    _auctions[auctionIndex] = Auction(
      deviceId: auction.deviceId,
      owner: auction.owner,
      startTime: auction.startTime,
      endTime: auction.endTime,
      minimumBid: auction.minimumBid,
      highestBid: amount,
      highestBidder: '0xMockBidder${DateTime.now().millisecondsSinceEpoch}',
      isActive: auction.isActive,
      isFinalized: auction.isFinalized,
    );
    
    notifyListeners();
    return true;
  }
  
  /// Finalize an auction
  Future<bool> finalizeAuction(String deviceId) async {
    _log('Finalizing mock auction for device: $deviceId');
    
    final auctionIndex = _auctions.indexWhere((a) => a.deviceId == deviceId);
    if (auctionIndex == -1) {
      _log('Auction not found for device: $deviceId');
      return false;
    }
    
    final auction = _auctions[auctionIndex];
    
    if (!auction.endTime.isBefore(DateTime.now())) {
      _log('Auction has not ended yet');
      return false;
    }
    
    // Update the auction to finalized state
    _auctions[auctionIndex] = Auction(
      deviceId: auction.deviceId,
      owner: auction.owner,
      startTime: auction.startTime,
      endTime: auction.endTime,
      minimumBid: auction.minimumBid,
      highestBid: auction.highestBid,
      highestBidder: auction.highestBidder,
      isActive: false,
      isFinalized: true,
    );
    
    notifyListeners();
    return true;
  }
  
  /// Create an auction with specified parameters
  Future<bool> createAuction({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minimumBid,
  }) async {
    _log('Creating mock auction for device: $deviceId');
    
    final endTime = startTime.add(duration);
    
    // Check if an auction already exists for this device
    if (_auctions.any((a) => a.deviceId == deviceId)) {
      _log('Auction already exists for device: $deviceId');
      return false;
    }
    
    // Create new auction
    _auctions.add(Auction(
      deviceId: deviceId,
      owner: '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
      startTime: startTime,
      endTime: endTime,
      minimumBid: minimumBid,
      highestBid: 0.0,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    ));
    
    notifyListeners();
    return true;
  }
  
  /// Add a mock auction directly (used for multi-slot auctions)
  void addMockAuction({
    required String deviceId,
    required DateTime startTime,
    required DateTime endTime,
    required double minimumBid,
  }) {
    _log('Adding mock auction for device: $deviceId');
    
    // Create new auction
    _auctions.add(Auction(
      deviceId: deviceId,
      owner: '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
      startTime: startTime,
      endTime: endTime,
      minimumBid: minimumBid,
      highestBid: 0.0,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    ));
    
    notifyListeners();
  }
}
