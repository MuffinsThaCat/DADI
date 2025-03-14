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
    
    // Initialize mock data (which now doesn't create any default auctions)
    _initializeMockData();
    
    // No longer creating an additional mock auction
    _log('Mock mode forced enabled, active auctions: ${_auctions.length}');
    _log('Starting with clean slate - no default auctions');
    
    // Make sure to notify listeners
    notifyListeners();
  }
  
  // Helper method to initialize mock data
  void _initializeMockData() {
    _log('Initializing mock data in Web3Service');
    
    // No longer creating default mock auctions - users will create their own
    _log('Not creating default mock auctions - clean slate for user-created auctions');
  }
}
