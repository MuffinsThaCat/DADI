import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/auction.dart';
import '../models/operation_result.dart';
import '../services/settings_service.dart';
import 'web3_service_interface.dart';
import 'web3_service_factory.dart';

/// Main Web3Service class that delegates to platform-specific implementations
class Web3Service extends ChangeNotifier implements Web3ServiceInterface {
  static final Web3Service _instance = Web3Service._internal();
  
  factory Web3Service() => _instance;
  
  factory Web3Service.withSettings({required SettingsService settingsService}) {
    _instance._settingsService = settingsService;
    _instance._initialize(settingsService);
    return _instance;
  }
  
  Web3Service._internal() {
    _log('Initializing Web3Service');
  }
  
  late Web3ServiceInterface _implementation;
  late SettingsService _settingsService;
  bool _mockMode = false;
  Map<String, Auction> _auctions = {};
  
  void _initialize(SettingsService settingsService) {
    _settingsService = settingsService;
    _implementation = Web3ServiceFactory.create(settingsService: settingsService);
    
    // Log the current environment
    _log('Initialized with RPC URL: ${_settingsService.getRpcUrl()}');
    
    // Forward change notifications from implementation
    _implementation.addListener(() {
      notifyListeners();
    });
    
    _log('Web3Service initialized with platform-specific implementation');
  }
  
  void _log(String message) {
    developer.log('Web3Service: $message');
  }
  
  @override
  bool get isConnected => _implementation.isConnected;
  
  @override
  bool get isMockMode => _mockMode;
  
  @override
  Future<bool> initializeContract() => _implementation.initializeContract();
  
  @override
  Future<bool> connectWithJsonRpc() => _implementation.connectWithJsonRpc();
  
  @override
  Future<OperationResult<Auction>> getAuction({required String deviceId}) => 
      _implementation.getAuction(deviceId: deviceId);
  
  @override
  Future<OperationResult<List<Auction>>> getActiveAuctions() => 
      _implementation.getActiveAuctions();
  
  @override
  Future<OperationResult<bool>> placeBid({
    required String deviceId,
    required double amount,
  }) => _implementation.placeBid(deviceId: deviceId, amount: amount);
  
  @override
  Future<OperationResult<bool>> finalizeAuction({required String deviceId}) => 
      _implementation.finalizeAuction(deviceId: deviceId);
  
  @override
  Future<void> forceEnableMockMode() async {
    _log('Forcing mock mode enabled in Web3Service');
    
    // Set mock mode
    _mockMode = true;
    
    // Clear any existing auctions to start fresh
    _auctions.clear();
    
    // Initialize with default mock auctions
    _initializeMockData();
    
    // Create an additional mock auction with current timestamp
    final now = DateTime.now();
    final deviceId = 'mock-device-${now.millisecondsSinceEpoch}';
    _log('Creating additional mock auction with ID: $deviceId');
    
    _auctions[deviceId] = Auction(
      deviceId: deviceId,
      owner: '0xMockOwner${now.millisecondsSinceEpoch}',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      minimumBid: 0.1,
      highestBid: 0.0,
      highestBidder: '0x0000000000000000000000000000000000000000',
      isActive: true,
      isFinalized: false,
    );
    
    _log('Mock mode forced enabled, active auctions: ${_auctions.length}');
    _log('Active auction keys: ${_auctions.keys.join(', ')}');
    
    // Make sure to notify listeners
    notifyListeners();
  }
  
  // Helper method to initialize mock data
  void _initializeMockData() {
    _log('Initializing mock data in Web3Service');
    
    // Create a few mock auctions
    final now = DateTime.now();
    
    // Mock auction 1 - active
    _auctions['mock-device-1'] = Auction(
      deviceId: 'mock-device-1',
      owner: '0xMockOwner1',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 5)),
      minimumBid: 0.1,
      highestBid: 0.2,
      highestBidder: '0xMockBidder1',
      isActive: true,
      isFinalized: false,
    );
    
    // Mock auction 2 - ending soon
    _auctions['mock-device-2'] = Auction(
      deviceId: 'mock-device-2',
      owner: '0xMockOwner2',
      startTime: now.subtract(const Duration(hours: 23)),
      endTime: now.add(const Duration(minutes: 30)),
      minimumBid: 0.05,
      highestBid: 0.15,
      highestBidder: '0xMockBidder2',
      isActive: true,
      isFinalized: false,
    );
    
    _log('Created ${_auctions.length} mock auctions');
  }
}
