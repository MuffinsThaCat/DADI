import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart' show rootBundle;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../models/auction.dart';
import '../models/operation_result.dart';
import '../services/settings_service.dart';
import 'web3_service_interface.dart';

/// Mobile implementation of Web3Service using web3dart package
class Web3ServiceMobile extends Web3ServiceInterface {
  static final Web3ServiceMobile _instance = Web3ServiceMobile._internal();
  
  factory Web3ServiceMobile() => _instance;
  
  factory Web3ServiceMobile.withSettings({required SettingsService settingsService}) {
    _instance._settingsService = settingsService;
    return _instance;
  }
  
  Web3ServiceMobile._internal() {
    _log('Initializing Web3ServiceMobile');
    if (isMockMode) {
      _log('Mock mode enabled, initializing mock data');
      _initializeMockData();
    }
  }
  
  late SettingsService _settingsService;
  Web3Client? _client;
  EthereumAddress? _currentAddress;
  DeployedContract? _contract;
  
  final Map<String, Auction> _auctions = {};
  bool _isConnected = false;
  bool _mockMode = false;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  bool get isMockMode => _mockMode;
  
  void _log(String message) {
    developer.log('Web3ServiceMobile: $message');
  }
  
  void _initializeMockData() {
    // Create some mock auctions for testing
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
    
    // Ended auction
    _auctions['device-3'] = Auction(
      deviceId: 'device-3',
      owner: '0xMockOwner',
      startTime: now.subtract(const Duration(hours: 48)),
      endTime: now.subtract(const Duration(hours: 24)),
      minimumBid: 0.1,
      highestBid: 0.5,
      highestBidder: '0xMockBidder2',
      isActive: false,
      isFinalized: true,
    );
  }
  
  @override
  Future<bool> initializeContract() async {
    if (isMockMode) {
      _log('Mock mode enabled, skipping contract initialization');
      return true;
    }
    
    try {
      final contractAddress = _settingsService.getContractAddress();
      _log('Initializing contract at address: $contractAddress');
      
      // Load contract ABI
      final abiJson = await rootBundle.loadString('assets/abi/dadi_auction.json');
      final contractAbi = ContractAbi.fromJson(abiJson, 'DADIAuction');
      
      // Create contract instance
      _contract = DeployedContract(
        contractAbi,
        EthereumAddress.fromHex(contractAddress),
      );
      
      return true;
    } catch (e) {
      _log('Error initializing contract: $e');
      return false;
    }
  }
  
  @override
  Future<bool> connectWithJsonRpc() async {
    if (isMockMode) {
      _log('Mock mode enabled, simulating connection');
      _isConnected = true;
      notifyListeners();
      return true;
    }
    
    try {
      final rpcUrl = _settingsService.getRpcUrl();
      _log('Connecting to RPC URL: $rpcUrl');
      
      // Create Web3 client
      _client = Web3Client(rpcUrl, http.Client());
      
      // Check connection by getting network ID
      final networkId = await _client!.getNetworkId();
      _log('Connected to network ID: $networkId');
      
      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error connecting to RPC: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
  
  @override
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (isMockMode) {
      _log('Mock mode enabled, getting mock auction for device: $deviceId');
      
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
    
    try {
      if (_contract == null || _client == null) {
        return OperationResult<Auction>(
          success: false,
          message: 'Contract or client not initialized',
        );
      }
      
      // Get auction function
      final getAuctionFunction = _contract!.function('getAuction');
      
      // Call function
      final result = await _client!.call(
        contract: _contract!,
        function: getAuctionFunction,
        params: [deviceId],
      );
      
      if (result.isEmpty) {
        return OperationResult<Auction>(
          success: false,
          message: 'Auction not found',
        );
      }
      
      // Parse result
      final auction = Auction(
        deviceId: deviceId,
        owner: (result[0][0] as EthereumAddress).hex,
        startTime: DateTime.fromMillisecondsSinceEpoch(
          (result[0][1] as BigInt).toInt() * 1000,
        ),
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (result[0][2] as BigInt).toInt() * 1000,
        ),
        minimumBid: (result[0][3] as BigInt).toDouble() / 1e18,
        highestBid: (result[0][4] as BigInt).toDouble() / 1e18,
        highestBidder: (result[0][5] as EthereumAddress).hex,
        isActive: result[0][6] as bool,
        isFinalized: result[0][7] as bool,
      );
      
      return OperationResult<Auction>(
        success: true,
        data: auction,
      );
    } catch (e) {
      _log('Error getting auction: $e');
      return OperationResult<Auction>(
        success: false,
        message: 'Error getting auction: $e',
      );
    }
  }
  
  @override
  Future<OperationResult<List<Auction>>> getActiveAuctions() async {
    if (isMockMode) {
      _log('Mock mode enabled, getting mock active auctions');
      
      final activeAuctions = _auctions.values
          .where((auction) => auction.isActive)
          .toList();
      
      return OperationResult<List<Auction>>(
        success: true,
        data: activeAuctions,
      );
    }
    
    try {
      if (_contract == null || _client == null) {
        return OperationResult<List<Auction>>(
          success: false,
          message: 'Contract or client not initialized',
        );
      }
      
      // Get active auctions function
      final getActiveAuctionsFunction = _contract!.function('getActiveAuctions');
      
      // Call function
      final result = await _client!.call(
        contract: _contract!,
        function: getActiveAuctionsFunction,
        params: [],
      );
      
      if (result.isEmpty || result[0].isEmpty) {
        return OperationResult<List<Auction>>(
          success: true,
          data: [],
        );
      }
      
      // Parse result
      final deviceIds = result[0][0] as List<String>;
      final auctions = <Auction>[];
      
      for (final deviceId in deviceIds) {
        final auctionResult = await getAuction(deviceId: deviceId);
        if (auctionResult.success) {
          auctions.add(auctionResult.data!);
        }
      }
      
      return OperationResult<List<Auction>>(
        success: true,
        data: auctions,
      );
    } catch (e) {
      _log('Error getting active auctions: $e');
      return OperationResult<List<Auction>>(
        success: false,
        message: 'Error getting active auctions: $e',
      );
    }
  }
  
  @override
  Future<OperationResult<bool>> placeBid({
    required String deviceId,
    required double amount,
  }) async {
    if (isMockMode) {
      _log('Mock mode enabled, placing mock bid for device: $deviceId, amount: $amount');
      
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
        highestBidder: _currentAddress?.hex ?? '0xMockBidder',
        isActive: auction.isActive,
        isFinalized: auction.isFinalized,
      );
      
      notifyListeners();
      
      return OperationResult<bool>(
        success: true,
        data: true,
      );
    }
    
    try {
      if (_contract == null || _client == null || _currentAddress == null) {
        return OperationResult<bool>(
          success: false,
          message: 'Contract, client or wallet not initialized',
        );
      }
      
      // Place bid function
      final placeBidFunction = _contract!.function('placeBid');
      
      // Convert amount to wei
      final amountWei = BigInt.from(amount * 1e18);
      
      // Create transaction
      final transaction = Transaction.callContract(
        contract: _contract!,
        function: placeBidFunction,
        parameters: [deviceId],
        value: EtherAmount.inWei(amountWei),
      );
      
      // Send transaction
      final credentials = await _getCredentials();
      final txHash = await _client!.sendTransaction(
        credentials,
        transaction,
        chainId: null,
      );
      
      _log('Bid placed, transaction hash: $txHash');
      
      return OperationResult<bool>(
        success: true,
        data: true,
      );
    } catch (e) {
      _log('Error placing bid: $e');
      return OperationResult<bool>(
        success: false,
        message: 'Error placing bid: $e',
      );
    }
  }
  
  @override
  Future<OperationResult<bool>> finalizeAuction({required String deviceId}) async {
    if (isMockMode) {
      _log('Mock mode enabled, finalizing mock auction for device: $deviceId');
      
      if (!_auctions.containsKey(deviceId)) {
        return OperationResult<bool>(
          success: false,
          message: 'Auction not found',
        );
      }
      
      final auction = _auctions[deviceId]!;
      
      if (!auction.endTime.isBefore(DateTime.now())) {
        return OperationResult<bool>(
          success: false,
          message: 'Auction has not ended yet',
        );
      }
      
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
    
    try {
      if (_contract == null || _client == null || _currentAddress == null) {
        return OperationResult<bool>(
          success: false,
          message: 'Contract, client or wallet not initialized',
        );
      }
      
      // Finalize auction function
      final finalizeAuctionFunction = _contract!.function('finalizeAuction');
      
      // Create transaction
      final transaction = Transaction.callContract(
        contract: _contract!,
        function: finalizeAuctionFunction,
        parameters: [deviceId],
      );
      
      // Send transaction
      final credentials = await _getCredentials();
      final txHash = await _client!.sendTransaction(
        credentials,
        transaction,
        chainId: null,
      );
      
      _log('Auction finalized, transaction hash: $txHash');
      
      return OperationResult<bool>(
        success: true,
        data: true,
      );
    } catch (e) {
      _log('Error finalizing auction: $e');
      return OperationResult<bool>(
        success: false,
        message: 'Error finalizing auction: $e',
      );
    }
  }
  
  @override
  Future<void> forceEnableMockMode() async {
    _log('Forcing mock mode enabled in Web3ServiceMobile');
    
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
  
  // Helper method to get credentials (would be replaced with actual wallet implementation)
  Future<Credentials> _getCredentials() async {
    // This is a placeholder - in a real app, you would integrate with a wallet
    // For testing, we'll use a random private key
    const privateKey = '0x0000000000000000000000000000000000000000000000000000000000000001';
    return EthPrivateKey.fromHex(privateKey);
  }
  
  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
