import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';

// Create a mock class for Web3Service
class MockWeb3Service extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> activeAuctions = {};
  bool isMockMode = true;
  String currentAddress = '0xMockOwner123456789';
  
  // Mock implementation of createAuction
  Future<OperationResult<Auction>> createAuction({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minimumBid,
  }) async {
    final endTime = startTime.add(duration);
    
    activeAuctions[deviceId] = {
      'deviceId': deviceId,
      'owner': currentAddress,
      'startTime': startTime,
      'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
      'minimumBid': minimumBid,
      'highestBid': BigInt.from(0),
      'highestBidder': '0x0000000000000000000000000000000000000000',
      'active': true,
      'finalized': false,
    };
    
    notifyListeners();
    
    return OperationResult.success(
      data: Auction(
        deviceId: deviceId,
        owner: currentAddress,
        startTime: startTime,
        endTime: endTime,
        minimumBid: minimumBid,
        highestBid: 0,
        highestBidder: '0x0000000000000000000000000000000000000000',
        isActive: true,
        isFinalized: false,
      ),
      message: 'Auction created successfully',
    );
  }
  
  // Mock implementation of getAuction
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult.failure(message: 'Auction not found for device: $deviceId');
    }
    
    final auction = activeAuctions[deviceId]!;
    final endTime = DateTime.fromMillisecondsSinceEpoch(
        (auction['endTime'] as BigInt).toInt() * 1000);
    
    return OperationResult.success(
      data: Auction(
        deviceId: deviceId,
        owner: auction['owner'] as String,
        startTime: auction['startTime'] as DateTime,
        endTime: endTime,
        minimumBid: auction['minimumBid'] as double,
        highestBid: (auction['highestBid'] as BigInt).toDouble() / 1e18,
        highestBidder: auction['highestBidder'] as String,
        isActive: auction['active'] as bool,
        isFinalized: auction['finalized'] as bool,
      ),
      message: 'Auction retrieved successfully',
    );
  }
  
  // Mock implementation of placeBidNew
  Future<OperationResult<double>> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult.failure(message: 'Auction not found for device: $deviceId');
    }
    
    final auction = activeAuctions[deviceId]!;
    
    // Check if bid is higher than current highest bid
    final highestBidWei = auction['highestBid'] as BigInt;
    final highestBidEth = highestBidWei.toDouble() / 1e18;
    
    if (amount <= highestBidEth) {
      return OperationResult.failure(
        message: 'Bid must be higher than current highest bid of $highestBidEth ETH',
      );
    }
    
    // Update the auction
    auction['highestBid'] = BigInt.from((amount * 1e18).toInt());
    auction['highestBidder'] = '0xMockBidder${DateTime.now().millisecondsSinceEpoch}';
    
    notifyListeners();
    
    return OperationResult.success(
      data: amount,
      message: 'Bid placed successfully',
    );
  }
  
  // Mock implementation of cancelAuction
  Future<OperationResult<bool>> cancelAuction({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult.failure(message: 'Auction not found for device: $deviceId');
    }
    
    // Check if the caller is the owner
    final owner = activeAuctions[deviceId]!['owner'].toString().toLowerCase();
    
    if (currentAddress.toLowerCase() != owner) {
      return OperationResult.failure(message: 'Only the owner can cancel an auction');
    }
    
    // Check if there are no bids
    final highestBid = activeAuctions[deviceId]!['highestBid'] as BigInt;
    if (highestBid > BigInt.zero) {
      return OperationResult.failure(message: 'Cannot cancel an auction with active bids');
    }
    
    // Cancel the auction
    activeAuctions[deviceId]!['active'] = false;
    activeAuctions[deviceId]!['finalized'] = true;
    notifyListeners();
    
    return OperationResult.success(
      data: true,
      message: 'Auction canceled successfully',
    );
  }
}

void main() {
  late MockWeb3Service web3Service;

  setUp(() {
    web3Service = MockWeb3Service();
  });

  group('Web3Service cancelAuction Tests', () {
    test('Cancel auction with no bids succeeds', () async {
      // First create an auction
      final createResult = await web3Service.createAuction(
        deviceId: 'test_device',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );
      
      expect(createResult.success, true);
      
      // Cancel the auction
      final result = await web3Service.cancelAuction(deviceId: 'test_device');
      
      expect(result.success, true);
      expect(result.data, true);
      expect(result.message, contains('canceled successfully'));
    });

    test('Cancel auction with bids fails', () async {
      // First create an auction
      await web3Service.createAuction(
        deviceId: 'test_device',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );
      
      // Place a bid
      await web3Service.placeBidNew(
        deviceId: 'test_device',
        amount: 0.2,
      );
      
      // Try to cancel the auction
      final result = await web3Service.cancelAuction(deviceId: 'test_device');
      
      expect(result.success, false);
      expect(result.message, contains('Cannot cancel an auction with active bids'));
    });

    test('Cancel non-existent auction fails', () async {
      // Try to cancel an auction that doesn't exist
      final result = await web3Service.cancelAuction(deviceId: 'non_existent_device');
      
      expect(result.success, false);
      expect(result.message, contains('Auction not found'));
    });
    
    test('Cancel auction when not owner fails', () async {
      // First create an auction
      await web3Service.createAuction(
        deviceId: 'test_device',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );
      
      // Change the current address to a different one
      web3Service.currentAddress = '0xDifferentAddress';
      
      // Try to cancel the auction
      final result = await web3Service.cancelAuction(deviceId: 'test_device');
      
      expect(result.success, false);
      expect(result.message, contains('Only the owner can cancel an auction'));
    });

    test('Auction state is updated after cancellation', () async {
      // First create an auction
      await web3Service.createAuction(
        deviceId: 'test_device',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );
      
      // Cancel the auction
      final cancelResult = await web3Service.cancelAuction(deviceId: 'test_device');
      expect(cancelResult.success, true);
      
      // Get the auction to verify its state
      final getResult = await web3Service.getAuction(deviceId: 'test_device');
      expect(getResult.success, true);
      
      final auction = getResult.data;
      expect(auction, isNotNull);
      expect(auction?.isActive, false);
      expect(auction?.isFinalized, true);
    });
  });
}
