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
    
    // Create some mock auctions for testing
    final now = DateTime.now();
    
    // Active auction
    _auctions.add(Auction(
      deviceId: 'device-1',
      owner: '0xMockOwner1',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 23)),
      minimumBid: 0.1,
      highestBid: 0.1,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    ));
    
    // Auction ending soon
    _auctions.add(Auction(
      deviceId: 'device-2',
      owner: '0xMockOwner2',
      startTime: now.subtract(const Duration(hours: 23)),
      endTime: now.add(const Duration(hours: 1)),
      minimumBid: 0.2,
      highestBid: 0.3,
      highestBidder: '0xMockBidder1',
      isActive: true,
      isFinalized: false,
    ));
    
    // Ended auction
    _auctions.add(Auction(
      deviceId: 'device-3',
      owner: '0xMockOwner3',
      startTime: now.subtract(const Duration(hours: 48)),
      endTime: now.subtract(const Duration(hours: 24)),
      minimumBid: 0.1,
      highestBid: 0.5,
      highestBidder: '0xMockBidder2',
      isActive: false,
      isFinalized: true,
    ));
    
    // Create an additional mock auction with current timestamp
    final deviceId = 'mock-device-${DateTime.now().millisecondsSinceEpoch}';
    _log('Creating additional mock auction with ID: $deviceId');
    
    _auctions.add(Auction(
      deviceId: deviceId,
      owner: '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      minimumBid: 0.1,
      highestBid: 0.0,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    ));
    
    _log('Created ${_auctions.length} mock auctions');
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
    
    if (auction.isFinalized) {
      _log('Auction is already finalized');
      return false;
    }
    
    // Update the auction to be finalized
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
  
  /// Create a new auction
  Future<bool> createAuction({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minimumBid,
  }) async {
    _log('Creating mock auction for device: $deviceId');
    
    // Check if an auction with this device ID already exists
    final existingAuctionIndex = _auctions.indexWhere((a) => a.deviceId == deviceId);
    if (existingAuctionIndex != -1) {
      _log('Auction already exists for device: $deviceId');
      return false;
    }
    
    final endTime = startTime.add(duration);
    _log('Creating mock auction with endTime: $endTime');
    
    // Create a new auction
    final newAuction = Auction(
      deviceId: deviceId,
      owner: '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
      startTime: startTime,
      endTime: endTime,
      minimumBid: minimumBid,
      highestBid: 0.0,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    );
    
    _auctions.add(newAuction);
    _log('Added mock auction to _auctions, count: ${_auctions.length}');
    
    notifyListeners();
    return true;
  }
}
