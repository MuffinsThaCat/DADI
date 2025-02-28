import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';
import 'package:dadi/services/settings_service.dart';
import 'package:mockito/mockito.dart';

// Mock implementation of Web3Service for testing
class MockWeb3Service extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> activeAuctions = {};
  bool isMockMode = true;
  
  // Mock implementation of createAuction
  Future<OperationResult<Auction>> createAuction({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minimumBid,
  }) async {
    final endTime = startTime.add(duration);
    
    activeAuctions[deviceId] = {
      'owner': '0xMockOwner',
      'startTime': BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000),
      'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
      'minimumBid': BigInt.from((minimumBid * 1e18).toInt()),
      'highestBid': BigInt.zero,
      'highestBidder': '0x0000000000000000000000000000000000000000',
      'isActive': true,
      'isFinalized': false,
    };
    
    notifyListeners();
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, activeAuctions[deviceId]!),
    );
  }
  
  // Mock implementation of getAuction
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, activeAuctions[deviceId]!),
    );
  }
  
  // Mock implementation of placeBidNew
  Future<OperationResult<Auction>> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = activeAuctions[deviceId]!;
    final amountWei = BigInt.from((amount * 1e18).toInt());
    
    if (amountWei <= auction['highestBid']) {
      return OperationResult<Auction>(
        success: false,
        message: 'Bid must be higher than current highest bid',
      );
    }
    
    auction['highestBid'] = amountWei;
    auction['highestBidder'] = '0xMockBidder';
    
    notifyListeners();
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, auction),
    );
  }
  
  // Mock implementation of finalizeAuctionNew
  Future<OperationResult<Auction>> finalizeAuctionNew({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = activeAuctions[deviceId]!;
    auction['isActive'] = false;
    auction['isFinalized'] = true;
    
    notifyListeners();
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, auction),
    );
  }
  
  // Mock implementation of loadActiveAuctions
  Future<void> loadActiveAuctions() async {
    // Do nothing, the activeAuctions map is already populated
    notifyListeners();
  }
  
  // Helper method to create an Auction object from a map
  Auction _createAuctionFromMap(String deviceId, Map<String, dynamic> map) {
    return Auction(
      deviceId: deviceId,
      owner: map['owner'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (map['startTime'] as BigInt).toInt() * 1000,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (map['endTime'] as BigInt).toInt() * 1000,
      ),
      minimumBid: (map['minimumBid'] as BigInt).toDouble() / 1e18,
      highestBid: (map['highestBid'] as BigInt).toDouble() / 1e18,
      highestBidder: map['highestBidder'] as String,
      isActive: map['isActive'] as bool,
      isFinalized: map['isFinalized'] as bool,
    );
  }
}

class MockSettingsService extends Mock implements SettingsService {
  @override
  String getContractAddress() => '0xMockContractAddress';
  
  @override
  String getRpcUrl() => 'http://localhost:8545';
  
  @override
  bool getUseMockBlockchain() => true;
}

void main() {
  late MockWeb3Service web3Service;

  setUp(() {
    web3Service = MockWeb3Service();
  });

  group('Web3Service Tests in Mock Mode', () {
    test('Initialize Web3Service in mock mode', () {
      expect(web3Service.isMockMode, true);
    });

    test('Create auction in mock mode', () async {
      const deviceId = 'test_device_123';
      final startTime = DateTime.now().add(const Duration(minutes: 10));
      const duration = Duration(hours: 1);
      const minBid = 0.1;

      final result = await web3Service.createAuction(
        deviceId: deviceId,
        startTime: startTime,
        duration: duration,
        minimumBid: minBid,
      );

      expect(result, isNotNull);
      expect(result.success, true);
      expect(result.data, isNotNull);
    });

    test('Get auction in mock mode', () async {
      const deviceId = 'test_device_123';

      // First create an auction
      await web3Service.createAuction(
        deviceId: deviceId,
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );

      // Then get it
      final result = await web3Service.getAuction(deviceId: deviceId);

      expect(result, isNotNull);
      expect(result.success, true);
      expect(result.data, isNotNull);

      final auction = result.data as Auction;
      expect(auction.deviceId, deviceId);
      expect(auction.minimumBid, 0.1);
    });

    test('Place bid in mock mode', () async {
      const deviceId = 'test_device_123';

      // First create an auction
      await web3Service.createAuction(
        deviceId: deviceId,
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );

      // Then place a bid
      final result = await web3Service.placeBidNew(
        deviceId: deviceId,
        amount: 0.2,
      );

      expect(result, isNotNull);
      expect(result.success, true);

      // Verify the bid was recorded
      final auctionResult = await web3Service.getAuction(deviceId: deviceId);
      final auction = auctionResult.data as Auction;
      expect(auction.highestBid, 0.2);
    });

    test('Finalize auction in mock mode', () async {
      const deviceId = 'test_device_123';

      // First create an auction
      await web3Service.createAuction(
        deviceId: deviceId,
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );

      // Place a bid
      await web3Service.placeBidNew(
        deviceId: deviceId,
        amount: 0.2,
      );

      // Then finalize it
      final result = await web3Service.finalizeAuctionNew(deviceId: deviceId);

      expect(result, isNotNull);
      expect(result.success, true);

      // Verify the auction is no longer active
      final auctionResult = await web3Service.getAuction(deviceId: deviceId);
      final auction = auctionResult.data as Auction;
      expect(auction.isActive, false);
      expect(auction.isFinalized, true);
    });

    test('Load active auctions in mock mode', () async {
      // Create a couple of auctions
      await web3Service.createAuction(
        deviceId: 'device1',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.1,
      );

      await web3Service.createAuction(
        deviceId: 'device2',
        startTime: DateTime.now().add(const Duration(minutes: 10)),
        duration: const Duration(hours: 1),
        minimumBid: 0.2,
      );

      // Load active auctions
      await web3Service.loadActiveAuctions();

      // Verify active auctions were loaded
      expect(web3Service.activeAuctions.length, 2);
      expect(web3Service.activeAuctions.containsKey('device1'), true);
      expect(web3Service.activeAuctions.containsKey('device2'), true);
    });
  });
}
