import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';
import 'package:dadi/services/settings_service.dart';
import 'package:dadi/services/web3_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock implementation of Web3ServiceInterface for testing
class MockWeb3Service with ChangeNotifier implements Web3ServiceInterface {
  bool _isConnected = false;
  final Map<String, Auction> _auctions = {};
  bool _mockMode = false;
  
  MockWeb3Service() {
    _initializeMockData();
  }
  
  void _initializeMockData() {
    final now = DateTime.now();
    
    // Active auction
    _auctions['device-1'] = Auction(
      deviceId: 'device-1',
      owner: '0xMockOwner',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 23)),
      minimumBid: 0.1,
      highestBid: 0.1,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    );
    
    // Auction ending soon
    _auctions['device-2'] = Auction(
      deviceId: 'device-2',
      owner: '0xMockOwner',
      startTime: now.subtract(const Duration(hours: 23)),
      endTime: now.add(const Duration(hours: 1)),
      minimumBid: 0.2,
      highestBid: 0.3,
      highestBidder: '0xMockBidder1',
      isActive: true,
      isFinalized: false,
    );
  }
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  bool get isMockMode => _mockMode;
  
  @override
  Future<bool> connectWithJsonRpc() async {
    _isConnected = true;
    notifyListeners();
    return true;
  }
  
  @override
  Future<bool> initializeContract() async {
    return true;
  }
  
  @override
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    return OperationResult<Auction>(
      success: true,
      data: _auctions[deviceId],
    );
  }
  
  @override
  Future<OperationResult<List<Auction>>> getActiveAuctions() async {
    final activeAuctions = _auctions.values
        .where((auction) => auction.isActive)
        .toList();
    
    return OperationResult<List<Auction>>(
      success: true,
      data: activeAuctions,
    );
  }
  
  @override
  Future<OperationResult<bool>> placeBid({
    required String deviceId,
    required double amount,
  }) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = _auctions[deviceId]!;
    
    if (auction.endTime.isBefore(DateTime.now())) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction has ended',
      );
    }
    
    if (amount <= auction.highestBid) {
      return OperationResult<bool>(
        success: false,
        message: 'Bid amount must be higher than current highest bid',
      );
    }
    
    // Update auction with new bid
    _auctions[deviceId] = Auction(
      deviceId: auction.deviceId,
      owner: auction.owner,
      startTime: auction.startTime,
      endTime: auction.endTime,
      minimumBid: auction.minimumBid,
      highestBid: amount,
      highestBidder: '0xMockBidder',
      isActive: auction.isActive,
      isFinalized: auction.isFinalized,
    );
    
    notifyListeners();
    
    return OperationResult<bool>(
      success: true,
      data: true,
    );
  }
  
  @override
  Future<OperationResult<bool>> finalizeAuction({required String deviceId}) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = _auctions[deviceId]!;
    
    if (auction.isFinalized) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction already finalized',
      );
    }
    
    // Update auction to finalized state
    _auctions[deviceId] = Auction(
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
    
    return OperationResult<bool>(
      success: true,
      data: true,
    );
  }
  
  @override
  Future<void> forceEnableMockMode() async {
    // Mock implementation
    _mockMode = true;
    notifyListeners();
  }
}

// Mock implementation of SettingsService for testing
class MockSettingsService with ChangeNotifier implements SettingsService {
  @override
  String getContractAddress() => '0xMockContractAddress';
  
  @override
  String getRpcUrl() => 'http://localhost:8545';
  
  @override
  bool getUseMockBlockchain() => true;
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> setContractAddress(String address) async {}
  
  @override
  Future<void> setRpcUrl(String url) async {}
  
  @override
  Future<void> setUseMockBlockchain(bool useMock) async {}
  
  @override
  Future<void> resetToDefaults() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  
  late MockWeb3Service mockWeb3Service;
  
  setUp(() {
    mockWeb3Service = MockWeb3Service();
  });
  
  group('Web3Service Cross-Platform Tests', () {
    test('should connect to blockchain', () async {
      // Arrange
      expect(mockWeb3Service.isConnected, false);
      
      // Act
      final result = await mockWeb3Service.connectWithJsonRpc();
      
      // Assert
      expect(result, true);
      expect(mockWeb3Service.isConnected, true);
    });
    
    test('should initialize contract', () async {
      // Act
      final result = await mockWeb3Service.initializeContract();
      
      // Assert
      expect(result, true);
    });
    
    test('should get active auctions', () async {
      // Act
      final result = await mockWeb3Service.getActiveAuctions();
      
      // Assert
      expect(result.success, true);
      expect(result.data, isNotNull);
      expect(result.data!.length, 2);
      expect(result.data![0].deviceId, 'device-1');
      expect(result.data![1].deviceId, 'device-2');
    });
    
    test('should get auction by device ID', () async {
      // Act
      final result = await mockWeb3Service.getAuction(deviceId: 'device-1');
      
      // Assert
      expect(result.success, true);
      expect(result.data, isNotNull);
      expect(result.data!.deviceId, 'device-1');
      expect(result.data!.isActive, true);
    });
    
    test('should return error for non-existent auction', () async {
      // Act
      final result = await mockWeb3Service.getAuction(deviceId: 'non-existent');
      
      // Assert
      expect(result.success, false);
      expect(result.message, 'Auction not found');
    });
    
    test('should place bid on auction', () async {
      // Act
      final result = await mockWeb3Service.placeBid(
        deviceId: 'device-1',
        amount: 0.2,
      );
      
      // Assert
      expect(result.success, true);
      expect(result.data, true);
      
      // Verify auction was updated
      final auction = await mockWeb3Service.getAuction(deviceId: 'device-1');
      expect(auction.data!.highestBid, 0.2);
      expect(auction.data!.highestBidder, '0xMockBidder');
    });
    
    test('should reject bid lower than current highest', () async {
      // Act
      final result = await mockWeb3Service.placeBid(
        deviceId: 'device-2',
        amount: 0.2, // Lower than current 0.3
      );
      
      // Assert
      expect(result.success, false);
      expect(result.message, 'Bid amount must be higher than current highest bid');
    });
    
    test('should finalize auction', () async {
      // Act
      final result = await mockWeb3Service.finalizeAuction(deviceId: 'device-1');
      
      // Assert
      expect(result.success, true);
      
      // Verify auction was finalized
      final auction = await mockWeb3Service.getAuction(deviceId: 'device-1');
      expect(auction.data!.isActive, false);
      expect(auction.data!.isFinalized, true);
    });
  });
}
