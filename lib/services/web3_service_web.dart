import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_web3/flutter_web3.dart';
import '../models/auction.dart';
import '../models/operation_result.dart';
import '../services/settings_service.dart';
import 'web3_service_interface.dart';

/// Web implementation of Web3Service using flutter_web3 package
class Web3ServiceWeb extends Web3ServiceInterface {
  static final Web3ServiceWeb _instance = Web3ServiceWeb._internal();
  
  factory Web3ServiceWeb() => _instance;
  
  factory Web3ServiceWeb.withSettings({required SettingsService settingsService}) {
    _instance._settingsService = settingsService;
    return _instance;
  }
  
  Web3ServiceWeb._internal() {
    _log('Initializing Web3ServiceWeb');
    if (isMockMode) {
      _log('Mock mode enabled, initializing mock data');
      _initializeMockData();
    }
  }
  
  late SettingsService _settingsService;
  Web3Provider? _provider;
  String? _currentAddress;
  Contract? _contract;
  
  final Map<String, Auction> _auctions = {};
  bool _isConnected = false;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  bool get isMockMode => _settingsService.getUseMockBlockchain();
  
  void _log(String message) {
    developer.log('Web3ServiceWeb: $message');
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
      
      // Create contract instance
      _contract = Contract(
        contractAddress,
        abiJson,
        _provider!,
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
      // Check if Ethereum is available in the browser
      if (!Ethereum.isSupported) {
        _log('Ethereum is not supported in this browser');
        return false;
      }
      
      // Request account access
      final accs = await ethereum!.requestAccount();
      _currentAddress = accs.first;
      _log('Connected to account: $_currentAddress');
      
      // Create Web3 provider
      _provider = Web3Provider(ethereum!);
      
      // Check connection by getting network
      final network = await _provider!.getNetwork();
      _log('Connected to network: ${network.name} (${network.chainId})');
      
      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error connecting to wallet: $e');
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
      if (_contract == null || _provider == null) {
        return OperationResult<Auction>(
          success: false,
          message: 'Contract or provider not initialized',
        );
      }
      
      // Call getAuction function
      final result = await _contract!.call<List<dynamic>>('getAuction', [deviceId]);
      
      if (result.isEmpty) {
        return OperationResult<Auction>(
          success: false,
          message: 'Auction not found',
        );
      }
      
      // Parse result
      final auction = Auction(
        deviceId: deviceId,
        owner: result[0],
        startTime: DateTime.fromMillisecondsSinceEpoch(
          (result[1] as BigInt).toInt() * 1000,
        ),
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (result[2] as BigInt).toInt() * 1000,
        ),
        minimumBid: (result[3] as BigInt).toDouble() / 1e18,
        highestBid: (result[4] as BigInt).toDouble() / 1e18,
        highestBidder: result[5],
        isActive: result[6] as bool,
        isFinalized: result[7] as bool,
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
      if (_contract == null || _provider == null) {
        return OperationResult<List<Auction>>(
          success: false,
          message: 'Contract or provider not initialized',
        );
      }
      
      // Call getActiveAuctions function
      final result = await _contract!.call<List<String>>('getActiveAuctions', []);
      
      if (result.isEmpty) {
        return OperationResult<List<Auction>>(
          success: true,
          data: [],
        );
      }
      
      // Get details for each auction
      final auctions = <Auction>[];
      
      for (final deviceId in result) {
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
        highestBidder: _currentAddress ?? '0xMockBidder',
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
      if (_contract == null || _provider == null || _currentAddress == null) {
        return OperationResult<bool>(
          success: false,
          message: 'Contract, provider or wallet not initialized',
        );
      }
      
      // Convert amount to wei
      final amountWei = BigInt.from(amount * 1e18);
      
      // Create transaction
      final tx = await _contract!.send(
        'placeBid',
        [deviceId],
        TransactionOverride(
          value: amountWei,
        ),
      );
      
      // Wait for transaction to be mined
      final receipt = await tx.wait();
      _log('Bid placed, transaction hash: ${receipt.transactionHash}');
      
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
      if (_contract == null || _provider == null || _currentAddress == null) {
        return OperationResult<bool>(
          success: false,
          message: 'Contract, provider or wallet not initialized',
        );
      }
      
      // Create transaction
      final tx = await _contract!.send(
        'finalizeAuction',
        [deviceId],
      );
      
      // Wait for transaction to be mined
      final receipt = await tx.wait();
      _log('Auction finalized, transaction hash: ${receipt.transactionHash}');
      
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
}
