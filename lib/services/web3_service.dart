      import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'flutter_web3.dart';
import '../contracts/dadi_auction.dart';
import '../models/operation_result.dart';
import '../services/settings_service.dart';

class Web3Service extends ChangeNotifier {
  static final Web3Service _instance = Web3Service._internal();
  
  factory Web3Service() {
    // Initialize if needed
    if (_instance._mockMode) {
      _instance._setupMockWalletSync();
    }
    return _instance;
  }
  
  factory Web3Service.withSettings({required SettingsService settingsService}) {
    _instance._settingsService = settingsService;
    return _instance;
  }
  
  Web3Service._internal() {
    _log('Initializing Web3Service');
    if (isMockMode) {
      _log('Mock mode enabled, initializing mock data');
      _initializeMockData();
    }
  }
  
  Provider? _provider;
  String? _currentAddress;
  Contract? _contract;
  bool _isContractInitialized = false;
  final Map<String, Map<String, dynamic>> _activeAuctions = {};
  SettingsService? _settingsService;
  
  // RPC URL for local Hardhat node
  final String _localRpcUrl = 'http://localhost:8087';
  
  // Mock mode for testing without blockchain
  bool _mockMode = false; // Default to real blockchain connection
  bool get isMockMode => _mockMode;
  set isMockMode(bool value) {
    _mockMode = value;
    if (_mockMode) {
      _log('Mock mode enabled');
      _initializeMockData();
    } else {
      _log('Mock mode disabled');
    }
    notifyListeners();
  }

  void enableMockMode() {
    isMockMode = true;
  }
  
  // Check if contract is initialized
  bool get isContractInitialized => _isContractInitialized || _mockMode;
  
  // Initialize mock data when in mock mode
  void _initializeMockData() {
    if (isMockMode) {
      _log('Initializing mock auction data - PRESERVING ONLY USER AUCTIONS');
      
      // Ensure we have a current address for mock mode
      if (_currentAddress == null || _currentAddress!.isEmpty) {
        _currentAddress = '0xMockUserAddress123'; // Use a consistent address for the mock user
        _log('Set consistent mock address: $_currentAddress');
      }
      
      _log('Current active auctions count: ${_activeAuctions.length}');
      
      // Save any user-created auctions before initializing
      Map<String, Map<String, dynamic>> userAuctions = {};
      _activeAuctions.forEach((deviceId, auctionData) {
        // Keep auctions that were created by users
        if (auctionData['isUserCreated'] == true) {
          _log('Preserving user-created auction: $deviceId, owner: ${auctionData['owner']}');
          userAuctions[deviceId] = Map.from(auctionData);
        }
      });
      
      // Clear existing auctions including any mock ones
      _log('Clearing all auctions except user-created ones');
      _activeAuctions.clear();
      
      // Restore only user-created auctions
      userAuctions.forEach((deviceId, auctionData) {
        _log('Restoring user-created auction: $deviceId, owner: ${auctionData['owner']}');
        _activeAuctions[deviceId] = auctionData;
      });
      
      // Always update auction statuses
      _updateAuctionStatus();
      _log('Mock data initialization complete, ${_activeAuctions.length} user auctions preserved');
      notifyListeners();
    }
  }

  // Create initial test auctions for mock mode
  void _createInitialTestAuctions() {
    _log('Creating initial test auctions has been DISABLED');
    
    // Not creating any mock auctions, so users will only see the auctions they create themselves
    _log('Mock auction creation is completely disabled - you will only see auctions you create yourself');
    
    // This method intentionally does nothing to ensure no mock auctions are created
    return;
  }

  void _log(String message, {Object? error}) {
    final logMessage = 'Web3Service: $message';
    
    // Log to developer console
    if (error != null) {
      developer.log(logMessage, error: error);
      // Also print to console for better visibility during debugging
      developer.log('ERROR: $logMessage - ${error.toString()}');
    } else {
      developer.log(logMessage);
      // Also print to console for better visibility during debugging
      developer.log('INFO: $logMessage');
    }
  }

  void _logActiveAuctions(String prefix) {
    _log('$prefix - Active auctions count: ${_activeAuctions.length}');
    _activeAuctions.forEach((key, value) {
      _log('$prefix - Auction: $key');
      _log('$prefix -  Fields: ${value.keys.join(', ')}');
      _log('$prefix -  Owner: ${value['owner']}');
      _log('$prefix -  Active: ${value['active']}');
      _log('$prefix -  isUserCreated: ${value['isUserCreated']}');
      _log('$prefix -  Has minBid: ${value.containsKey('minBid')}');
      _log('$prefix -  Has minimumBid: ${value.containsKey('minimumBid')}');
    });
  }

  // Get the current user address with fallback for mock mode
  String? get currentAddress {
    // Ensure we have a consistent mock address if in mock mode
    if (_mockMode && (_currentAddress == null || _currentAddress!.isEmpty)) {
      _currentAddress = '0xMockUserAddress123';
      _log('Using default mock address because current one is empty: $_currentAddress');
    }
    return _currentAddress;
  }
  
  // Set the current user address
  set currentAddress(String? address) {
    if (address != _currentAddress) {
      _log('Setting current address from ${_currentAddress ?? 'null'} to ${address ?? 'null'}');
      _currentAddress = address;
      notifyListeners();
    }
  }
  
  // Getters
  Map<String, Map<String, dynamic>> get activeAuctions {
    // Debug output of active auctions
    _log('Getting activeAuctions - count: ${_activeAuctions.length}');
    if (_activeAuctions.isNotEmpty) {
      _log('Active auction keys: ${_activeAuctions.keys.join(', ')}');
    }
    
    // Ensure auctions are up to date
    _updateAuctionStatus();
    
    return _activeAuctions;
  }
  
  bool get isConnected => isMockMode || (_currentAddress != null && _provider != null);
  
  Future<void> logEthereumProviderStatus() async {
    _log('Checking Ethereum provider status...');
    
    try {
      if (Ethereum.isSupported) {
        _log('Ethereum is supported in this browser');
        
        if (Ethereum.ethereum != null) {
          _log('Ethereum provider is available');
          _log('Provider type: ${Ethereum.ethereum.runtimeType}');
          
          // Check if MetaMask is installed
          try {
            _log('Checking for MetaMask...');
            // We can't directly access isMetaMask property, so we'll check indirectly
            final metaMaskAvailable = await isMetaMaskAvailable();
            _log('Is MetaMask available: $metaMaskAvailable');
          } catch (e) {
            _log('Error checking if MetaMask is installed:', error: e);
          }
          
          // Try to get chain ID
          try {
            Ethereum.ethereum!.getChainId().then((chainId) {
              _log('Current chain ID: $chainId');
              
              // Check if it's the expected Hardhat chain ID
              if (chainId == 31337) {
                _log('Connected to Hardhat network (chain ID: 31337)');
              } else {
                _log('Not connected to Hardhat network. Current chain ID: $chainId');
              }
            }).catchError((e) {
              _log('Error getting chain ID:', error: e);
            });
          } catch (e) {
            _log('Error accessing chain ID:', error: e);
          }
        } else {
          _log('Ethereum provider is null, even though Ethereum is supported');
        }
      } else {
        _log('Ethereum is not supported in this browser');
      }
      
      // Check direct RPC connection
      _log('Checking direct RPC connection to ${getRpcUrl()}...');
      
      try {
        final jsonRpcProvider = JsonRpcProvider(getRpcUrl());
        jsonRpcProvider.getNetwork().then((network) {
          _log('Successfully connected to RPC with network: ${network.name}, chainId: ${network.chainId}');
        }).catchError((e) {
          _log('Error getting network from RPC:', error: e);
        });
      } catch (e) {
        _log('Error creating JsonRpcProvider:', error: e);
      }
    } catch (e) {
      _log('Error checking Ethereum provider:', error: e);
    }
  }

  Future<bool> connect() async {
    if (_mockMode) {
      _log('Mock mode enabled, skipping real connection');
      return true;
    }

    try {
      _log('Connecting to Web3...');
      
      // Check if ethereum is available
      if (Ethereum.ethereum == null) {
        _log('Ethereum provider not available, attempting to use local RPC');
        
        try {
          _log('Creating JsonRpcProvider with URL: ${getRpcUrl()}');
          _provider = JsonRpcProvider(getRpcUrl());
          _log('JsonRpcProvider created successfully');
          
          // Test the provider by getting the network
          try {
            final network = await _provider!.getNetwork();
            _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
          } catch (e) {
            _log('Error getting network from provider, falling back to mock mode:', error: e);
            _enableMockMode();
            return true;
          }
        } catch (e) {
          _log('Error creating JsonRpcProvider, falling back to mock mode:', error: e);
          _enableMockMode();
          return true;
        }
      } else {
        // Connect to ethereum
        try {
          _log('Ethereum provider available, requesting accounts...');
          final accs = await Ethereum.ethereum!.requestAccount();
          if (accs.isEmpty) {
            _log('No accounts returned from wallet, falling back to mock mode');
            _enableMockMode();
            return true;
          }
          
          _currentAddress = accs.first;
          _log('Connected to wallet with address: $_currentAddress');
          
          // Initialize provider
          _log('Creating Web3Provider from ethereum');
          _provider = Web3Provider(Ethereum.ethereum!);
          _log('Web3Provider created successfully');
          
          // Test the provider by getting the network
          try {
            final network = await _provider!.getNetwork();
            _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
          } catch (e) {
            _log('Error getting network from Web3Provider, falling back to mock mode:', error: e);
            _enableMockMode();
            return true;
          }
        } catch (e) {
          _log('Failed to connect to wallet, falling back to mock mode:', error: e);
          _enableMockMode();
          return true;
        }
      }
      
      // Initialize contract
      _log('Initializing contract...');
      final contractInitialized = await initializeContract();
      
      if (contractInitialized) {
        _log('Contract initialized successfully');
      } else {
        _log('Failed to initialize contract, falling back to mock mode');
        _enableMockMode();
        return true;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error connecting to Web3, falling back to mock mode:', error: e);
      _enableMockMode();
      return true;
    }
  }

  /// Helper method to enable mock mode and load mock auctions
  Future<void> _enableMockMode() async {
    _log('Enabling mock mode');
    _mockMode = true;
    
    // Initialize mock data
    _initializeMockData();
    
    // Create a mock auction if there are none
    if (_activeAuctions.isEmpty) {
      _log('No active auctions found, creating a mock auction');
      final result = await createMockAuction();
      if (result.success) {
        _log('Successfully created mock auction: ${result.data}');
      } else {
        _log('Failed to create mock auction: ${result.message}');
      }
    } else {
      _log('Active auctions already exist, count: ${_activeAuctions.length}');
      _log('Active auction keys: ${_activeAuctions.keys.join(', ')}');
    }
    
    // Make sure to notify listeners
    notifyListeners();
    
    _log('Mock mode enabled, active auctions: ${_activeAuctions.length}');
  }

  // Force connection using JsonRpcProvider directly
  Future<bool> connectWithJsonRpc() async {
    if (_mockMode) {
      _log('Mock mode enabled, skipping real connection');
      return true;
    }

    try {
      _log('Connecting directly with JsonRpcProvider to ${getRpcUrl()}');
      
      try {
        // Create JsonRpcProvider
        _log('Creating JsonRpcProvider');
        _provider = JsonRpcProvider(getRpcUrl());
        _log('JsonRpcProvider created');
        
        // Test the provider by getting the network
        try {
          final network = await _provider!.getNetwork();
          _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
        } catch (e) {
          _log('Error getting network from JsonRpcProvider, falling back to mock mode:', error: e);
          _enableMockMode();
          return true;
        }
      } catch (e) {
        _log('Error creating JsonRpcProvider, falling back to mock mode:', error: e);
        _enableMockMode();
        return true;
      }
      
      // Initialize contract
      _log('Initializing contract...');
      final contractInitialized = await initializeContract();
      
      if (contractInitialized) {
        _log('Contract initialized successfully');
      } else {
        _log('Failed to initialize contract, falling back to mock mode');
        _enableMockMode();
        return true;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error connecting with JsonRpcProvider, falling back to mock mode:', error: e);
      _enableMockMode();
      return true;
    }
  }

  Future<bool> initializeContract() async {
    if (_isContractInitialized) {
      return true;
    }

    if (_mockMode) {
      _log('Mock mode enabled, simulating contract initialization');
      // Set a mock address if none exists
      if (_currentAddress == null) {
        _currentAddress = '0xMockAddress${DateTime.now().millisecondsSinceEpoch}';
        _log('Set mock address: $_currentAddress');
      }
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      _isContractInitialized = true;
      notifyListeners();
      return true;
    }

    try {
      if (_provider == null) {
        _log('Provider not initialized. Trying to connect...');
        final connected = await connectWithJsonRpc();
        if (!connected) {
          _log('Failed to connect to provider');
          return false;
        }
      }

      try {
        // Create contract instance
        final contractAddress = getContractAddress();
        _log('Creating contract instance with address: $contractAddress');
        _contract = Contract(
          contractAddress,
          DADIAuction.abi,
          _provider!,
        );
        _log('Contract instance created successfully');
        
        // Try to call a simple view function to verify contract connection
        try {
          _log('Testing contract connection...');
          final result = await _contract!.call('owner', []);
          _log('Contract connection successful. Owner: $result');
        } catch (e) {
          _log('Error testing contract connection:', error: e);
          return false;
        }
        
        _isContractInitialized = true;
        notifyListeners();
        return true;
      } catch (e) {
        _log('Error creating contract instance:', error: e);
        return false;
      }
    } catch (e) {
      _log('Error initializing contract:', error: e);
      return false;
    }
  }

  Future<void> loadActiveAuctions({bool forceRefresh = false}) async {
    _log('loadActiveAuctions called, isMockMode: $isMockMode');
    _log('Current user address: $_currentAddress');
    
    if (_mockMode) {
      _log('We are in mock mode');
      
      // Make sure we have a mock wallet address set
      _setupMockWalletSync();
      
      // Debug what auctions exist before a potential refresh
      if (_activeAuctions.isNotEmpty) {
        _logActiveAuctions('Before refresh');
      }
      
      // Only initialize if there are no auctions yet
      if (_activeAuctions.isEmpty || forceRefresh) {
        _initializeMockData();
      }

      // Always update auction status
      _updateAuctionStatus();
      
      notifyListeners();
      return;
    }
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        return;
      }
      
      _log('Fetching auctions from contract...');
      
      // Clear existing auctions
      _activeAuctions.clear();
      
      try {
        // Get auction count
        final auctionCount = await _contract!.call('getAuctionCount', []);
        _log('Total auction count: $auctionCount');
        
        if (auctionCount > BigInt.zero) {
          // Since there's no getActiveAuctions function, we'll iterate through all auctions
          _log('Iterating through all auctions...');
          
          // We need to know what device IDs are available
          // For now, we'll use a predefined list of device IDs to check
          // In a real implementation, you'd need a way to get all device IDs
          final deviceIds = [
            '0x6465766963653100000000000000000000000000000000000000000000000000', // "device1" in bytes32
            '0x6465766963653200000000000000000000000000000000000000000000000000', // "device2" in bytes32
            '0x6465766963653300000000000000000000000000000000000000000000000000', // "device3" in bytes32
          ];
          
          for (final deviceId in deviceIds) {
            try {
              _log('Checking auction for device ID: $deviceId');
              final auctionData = await _contract!.call('getAuction', [deviceId]) as List<dynamic>;
              
              // Extract auction data
              final owner = auctionData[0];
              final startTime = DateTime.fromMillisecondsSinceEpoch(
                (auctionData[1] as BigInt).toInt() * 1000,
              );
              final endTime = DateTime.fromMillisecondsSinceEpoch(
                (auctionData[2] as BigInt).toInt() * 1000,
              );
              final minBid = auctionData[3] as BigInt;
              final highestBidder = auctionData[4];
              final highestBid = auctionData[5] as BigInt;
              final isActive = auctionData[6] as bool? ?? false;
              
              // Convert bytes32 to string for device ID
              final String deviceIdStr = _bytesToString(deviceId);
              
              // Determine if the auction has ended based on time
              final now = DateTime.now();
              final hasEnded = now.isAfter(endTime);
              
              // An auction is considered finalized if it's not active
              // or if it has ended and there's a highest bidder
              final isFinalized = !isActive || (hasEnded && highestBidder != '0x0000000000000000000000000000000000000000');
              
              _log('Auction data for $deviceIdStr: active=$isActive, ended=$hasEnded, finalized=$isFinalized, ends=$endTime, highest bid=$highestBid');
              
              // Store auction data (include both active and inactive auctions)
              _activeAuctions[deviceIdStr] = {
                'deviceId': deviceIdStr,
                'owner': owner,
                'startTime': startTime.toIso8601String(),
                'endTime': endTime.toIso8601String(),
                'minimumBid': minBid.toDouble() / 1e18, // Convert to double
                'highestBid': highestBid.toDouble() / 1e18, // Convert to double
                'highestBidder': highestBidder,
                'isActive': isActive,
                'isFinalized': isFinalized,
                'active': isActive,
                'finalized': isFinalized,
                'isUserCreated': false,
              };
              
              _log('Added auction for device: $deviceIdStr, ends: $endTime, highest bid: $highestBid');
            } catch (e) {
              _log('Error loading auction for device ID $deviceId:', error: e);
            }
          }
        } else {
          _log('No auctions found in real mode, consider using mock mode for testing');
        }
      } catch (e) {
        _log('Error getting auction data:', error: e);
        rethrow;
      }
      
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _log('Error loading auctions:', error: e);
      throw Exception('Failed to load auctions: $e');
    }
  }

  /// Convert bytes32 to string
  String _bytesToString(dynamic bytes32) {
    if (bytes32 == null) return '';
    
    // Remove '0x' prefix if present
    String hexString = bytes32.toString();
    if (hexString.startsWith('0x')) {
      hexString = hexString.substring(2);
    }
    
    // Convert hex to bytes
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      if (i + 2 <= hexString.length) {
        bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
      }
    }
    
    // Convert bytes to string and trim null bytes
    return String.fromCharCodes(bytes).replaceAll('\x00', '');
  }

  Future<void> placeBid(String deviceId, double amountEth) async {
    // Convert ETH to wei
    final amountWei = _toWei(amountEth);
    
    if (_mockMode) {
      _log('Mock mode enabled, simulating bid placement');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      
      if (!_activeAuctions.containsKey(deviceId)) {
        throw Exception('Auction not found for device: $deviceId');
      }
      
      final auction = _activeAuctions[deviceId]!;
      
      // Check if bid is higher than current highest bid
      final currentHighestBid = auction['highestBid'];
      double currentBidDouble = 0.0;
      
      if (currentHighestBid is BigInt) {
        currentBidDouble = currentHighestBid.toDouble() / 1e18;  // Convert from wei to ETH
      } else if (currentHighestBid is double) {
        currentBidDouble = currentHighestBid;
      } else if (currentHighestBid != null) {
        // Try to parse as double if it's another type
        currentBidDouble = double.tryParse(currentHighestBid.toString()) ?? 0.0;
      }
      
      if (amountEth <= currentBidDouble) {
        throw Exception('Bid amount must be higher than current highest bid');
      }
      
      // Update auction with new bid
      auction['highestBid'] = amountEth;
      auction['highestBidder'] = _currentAddress ?? '0xMockBidder123456789';
      
      Future.microtask(() {
        notifyListeners();
      });
      return;
    }
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        throw Exception('Contract not initialized');
      }
      
      if (_currentAddress == null) {
        _log('No wallet connected');
        throw Exception('No wallet connected');
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = _stringToBytes32(deviceId);
      
      _log('Placing bid for device: $deviceId, amount: $amountEth ETH ($amountWei wei)');
      
      // Set value for the transaction
      final overrides = TransactionOverride(
        value: amountWei,
      );
      
      // Call the contract method
      final transaction = await _contract!.send(
        'placeBid',
        [bytes32DeviceId],
        overrides,
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      
      // Status 1 means success in Ethereum transactions
      if (receipt.status == BigInt.one) {
        _log('Bid placed successfully');
        
        // Update the auction in our local state
        if (_activeAuctions.containsKey(deviceId)) {
          _activeAuctions[deviceId]!['highestBid'] = amountWei;
          _activeAuctions[deviceId]!['highestBidder'] = _currentAddress;
        }
      } else {
        _log('Transaction failed');
        throw Exception('Transaction failed');
      }
      
      // Refresh auctions list
      await loadActiveAuctions();
    } catch (e) {
      _log('Error placing bid:', error: e);
      throw Exception('Failed to place bid: $e');
    }
  }

  Future<bool> placeBidLegacy(String deviceId, double amountEth) async {
    if (_mockMode) {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    
    try {
      await _placeBidReal(deviceId, amountEth);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _placeBidReal(String deviceId, double bidEth) async {
    _log('Placing bid of $bidEth ETH on device: $deviceId');
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        throw Exception('Contract not initialized');
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = _stringToBytes32(deviceId);
      
      // Convert ETH to wei
      final bidWei = _toWei(bidEth);
      
      _log('Placing bid with parameters: deviceId: $deviceId (bytes32: $bytes32DeviceId), bid: $bidEth ETH (${bidWei.toString()} wei)');
      
      // Call the contract method
      final transaction = await _contract!.send(
        'placeBid',
        [bytes32DeviceId],
        TransactionOverride(
          value: bidWei,
        ),
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      
      // Status 1 means success in Ethereum transactions
      if (receipt.status == BigInt.one) {
        _log('Bid placed successfully');
        
        // Update the auction in our local state
        if (_activeAuctions.containsKey(deviceId)) {
          _activeAuctions[deviceId]!['highestBid'] = bidWei;
          _activeAuctions[deviceId]!['highestBidder'] = _currentAddress;
        }
      } else {
        _log('Transaction failed');
        throw Exception('Transaction failed');
      }
      
      // Refresh auctions after bid
      await _refreshAuctions();
    } catch (e) {
      _log('Error placing bid:', error: e);
      rethrow;
    }
  }

  Future<void> finalizeAuction(String deviceId) async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating auction finalization');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      
      if (!_activeAuctions.containsKey(deviceId)) {
        throw Exception('Auction not found for device: $deviceId');
      }
      
      final auction = _activeAuctions[deviceId]!;
      
      // Check if auction is still active
      if (!(auction['active'] as bool)) {
        throw Exception('Auction is already finalized');
      }
      
      // Finalize the auction
      auction['active'] = false;
      auction['finalized'] = true;
      
      Future.microtask(() {
        notifyListeners();
      });
      return;
    }
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        throw Exception('Contract not initialized');
      }
      
      if (_currentAddress == null) {
        _log('No wallet connected');
        throw Exception('No wallet connected');
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = _stringToBytes32(deviceId);
      
      _log('Finalizing auction for device: $deviceId');
      
      // Call the contract method
      final transaction = await _contract!.send(
        'finalizeAuction',
        [bytes32DeviceId],
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      
      // Status 1 means success in Ethereum transactions
      if (receipt.status == BigInt.one) {
        _log('Auction finalized successfully');
        
        // Update the auction in our local state
        if (_activeAuctions.containsKey(deviceId)) {
          _activeAuctions[deviceId]!['active'] = false;
          _activeAuctions[deviceId]!['finalized'] = true;
        }
      } else {
        _log('Transaction failed');
        throw Exception('Transaction failed');
      }
      
      // Refresh auctions list
      await loadActiveAuctions();
    } catch (e) {
      _log('Error finalizing auction:', error: e);
      throw Exception('Failed to finalize auction: $e');
    }
  }

  Future<bool> finalizeAuctionLegacy(String deviceId) async {
    if (_mockMode) {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    
    try {
      await _finalizeAuctionReal(deviceId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _finalizeAuctionReal(String deviceId) async {
    _log('Finalizing auction for device: $deviceId');
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        throw Exception('Contract not initialized');
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = _stringToBytes32(deviceId);
      
      _log('Finalizing auction with parameters: deviceId: $deviceId (bytes32: $bytes32DeviceId)');
      
      // Call the contract method
      final transaction = await _contract!.send(
        'finalizeAuction',
        [bytes32DeviceId],
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      
      // Status 1 means success in Ethereum transactions
      if (receipt.status == BigInt.one) {
        _log('Auction finalized successfully');
        
        // Update the auction in our local state
        if (_activeAuctions.containsKey(deviceId)) {
          _activeAuctions[deviceId]!['active'] = false;
          _activeAuctions[deviceId]!['finalized'] = true;
        }
      } else {
        _log('Transaction failed');
        throw Exception('Transaction failed');
      }
      
      // Refresh auctions after finalization
      await _refreshAuctions();
    } catch (e) {
      _log('Error finalizing auction:', error: e);
      rethrow;
    }
  }
  
  /// Convert string to bytes32
  List<int> _stringToBytes32(String str) {
    final List<int> bytes = utf8.encode(str);
    if (bytes.length > 32) {
      throw Exception('Device ID too long: must be 32 bytes or less when encoded as UTF-8');
    }
    
    // Pad to 32 bytes
    final List<int> bytes32 = List<int>.filled(32, 0);
    for (int i = 0; i < bytes.length; i++) {
      bytes32[i] = bytes[i];
    }
    
    return bytes32;
  }

  Future<bool> testContract() async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating contract test');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      _log('Mock contract test successful');
      return true;
    }
    
    try {
      _log('Testing contract...');
      
      if (_contract == null) {
        _log('Contract not initialized');
        return false;
      }
      
      // Call a simple view function to test the contract
      final count = await _contract!.call('getAuctionCount', []) as BigInt;
      _log('Contract test successful. Auction count: $count');
      return true;
    } catch (e) {
      _log('Contract test error:', error: e);
      return false;
    }
  }

  Future<void> disconnect() async {
    _log('Disconnecting from Web3');
    
    if (_mockMode) {
      _log('Mock mode enabled, simulating disconnect');
    } else {
      _currentAddress = null;
      _provider = null;
      _contract = null;
      _isContractInitialized = false;
    }
    
    Future.microtask(() {
      notifyListeners();
    });
    _log('Disconnected from Web3');
  }

  /// Toggle between mock mode and real blockchain mode
  Future<bool> toggleMockMode() async {
    _mockMode = !_mockMode;
    _log('Toggled mock mode: $_mockMode');
    
    if (!_mockMode) {
      // If switching to real mode, try to connect
      try {
        await connect();
        return true;
      } catch (e) {
        _log('Failed to connect to blockchain after toggling to real mode:', error: e);
        // If connection fails, switch back to mock mode
        await _enableMockMode();
        return false;
      }
    } else {
      // If switching to mock mode, use the enableMockMode helper
      await _enableMockMode();
      return true;
    }
  }
  
  /// Check if MetaMask is installed and available
  Future<bool> isMetaMaskAvailable() async {
    if (isMockMode) return true;
    
    try {
      return Ethereum.ethereum != null;
    } catch (e) {
      _log('Error checking MetaMask availability: $e');
      return false;
    }
  }

  Future<OperationResult> createAuction({
    required String deviceId,
    required DateTime startTime,
    required int duration,
    required double minimumBid,
    bool isUserCreated = false,
  }) async {
    _log('Creating auction for device: $deviceId');
    _log('Auction details: startTime=$startTime, duration=$duration, minimumBid=$minimumBid, isUserCreated=$isUserCreated');
    
    // Calculate end time
    final endTime = startTime.add(Duration(minutes: duration));
    _log('Calculated endTime: $endTime');
    
    try {
      // Attempt to initialize contract if not already done
      if (_contract == null) {
        _log('Contract not initialized, attempting to initialize');
        final initResult = await initializeContract();
        _log('Contract initialization result: $initResult');
      }
      
      // Generate a unique auctionId
      String auctionId = deviceId;
      _log('Using auctionId: $auctionId');
      
      // If we're not in mock mode and have a valid contract and provider, create on blockchain
      if (!_mockMode && _contract != null && _provider != null) {
        _log('Creating auction on blockchain');
        try {
          await _createAuctionReal(
            deviceId: deviceId,
            startTime: startTime,
            duration: Duration(minutes: duration),
            minBidEth: minimumBid,
          );
          
          return OperationResult(
            success: true,
            data: {'auctionId': auctionId},
            message: 'Auction created successfully on blockchain',
          );
        } catch (e) {
          _log('Error creating auction on blockchain:', error: e);
          return OperationResult(
            success: false,
            message: 'Failed to create auction on blockchain: ${e.toString()}',
          );
        }
      }
      
      _log('Using mock mode for auction creation');
      
      // Add the auction to our active auctions map
      _activeAuctions[auctionId] = {
        'deviceId': auctionId,
        'owner': _currentAddress ?? '0xMockUserAddress123',
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'minimumBid': minimumBid,
        'highestBid': 0.0,
        'highestBidder': '0x0000000000000000000000000000000000000000',
        'active': true,
        'finalized': false,
        'isUserCreated': isUserCreated,
      };
      
      _log('Auction added to _activeAuctions map');
      _log('Current active auctions: ${_activeAuctions.length}');
      _log('Active auction IDs: ${_activeAuctions.keys.join(', ')}');
      
      // Notify listeners that the auction data has changed
      notifyListeners();
      _log('Notified listeners of new auction');
      
      return OperationResult(
        success: true,
        data: {'auctionId': auctionId},
        message: 'Auction created successfully (mock)',
      );
    } catch (e, stack) {
      _log('Error creating auction:', error: e);
      _log('Stack trace: $stack');
      
      return OperationResult(
        success: false,
        message: 'Failed to create auction: ${e.toString()}',
      );
    }
  }
  
  /// Get an auction by device ID
  Future<OperationResult> getAuction({required String deviceId}) async {
    _log('Getting auction for device: $deviceId');
    
    if (_mockMode) {
      _log('Mock mode enabled, getting mock auction');
      
      if (!_activeAuctions.containsKey(deviceId)) {
        return OperationResult(
          success: false,
          message: 'Auction not found',
        );
      }
      
      final data = _activeAuctions[deviceId]!;
      
      final auction = {
        'deviceId': data['deviceId'],
        'owner': data['owner'],
        'startTime': data['startTime'],
        'endTime': data['endTime'],
        'minimumBid': data['minimumBid'],
        'highestBid': data['highestBid'],
        'highestBidder': data['highestBidder'] ?? '0x0000000000000000000000000000000000000000',
        'active': data['active'] ?? true,
        'isActive': data['active'] ?? true,
        'isFinalized': data['finalized'] ?? false,
        'finalized': data['finalized'] ?? false,
        'isUserCreated': data['isUserCreated'] ?? false,
      };
      
      return OperationResult(
        success: true,
        data: auction,
      );
    }
    
    try {
      if (_contract == null || _provider == null) {
        return OperationResult(
          success: false,
          message: 'Contract or provider not initialized',
        );
      }
      
      // Call getAuction function
      final result = await _contract!.call('getAuction', [deviceId]) as List<dynamic>;
      
      if (result.isEmpty) {
        return OperationResult(
          success: false,
          message: 'Auction not found',
        );
      }
      
      // Parse result
      final auction = {
        'deviceId': deviceId,
        'owner': result[0],
        'startTime': DateTime.fromMillisecondsSinceEpoch(
          (result[1] as BigInt).toInt() * 1000,
        ),
        'endTime': DateTime.fromMillisecondsSinceEpoch(
          (result[2] as BigInt).toInt() * 1000,
        ),
        'minimumBid': (result[3] as BigInt).toDouble() / 1e18,
        'highestBid': (result[4] as BigInt).toDouble() / 1e18,
        'highestBidder': result[5],
        'active': result[6] as bool? ?? false,
        'isActive': result[6] as bool? ?? false,
        'isFinalized': result[7] as bool? ?? false,
        'finalized': result[7] as bool? ?? false,
        'isUserCreated': false,
      };
      
      return OperationResult(
        success: true,
        data: auction,
      );
    } catch (e) {
      _log('Error getting auction: $e');
      return OperationResult(
        success: false,
        message: 'Error getting auction: $e',
      );
    }
  }
  
  // Place a bid on an auction
  Future<OperationResult> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    _log('Placing bid of $amount ETH on device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult(
            success: false,
            message: 'Auction not found for device: $deviceId',
          );
        }
        
        final auction = _activeAuctions[deviceId]!;
        final now = DateTime.now();
        final startTime = auction['startTime'] is DateTime 
            ? auction['startTime'] as DateTime
            : DateTime.now().subtract(const Duration(hours: 1));
        
        final endTime = DateTime.fromMillisecondsSinceEpoch(
            (auction['endTimeBigInt'] as BigInt).toInt() * 1000);
        
        // Check if auction is active
        if (now.isBefore(startTime)) {
          return OperationResult(
            success: false,
            message: 'Auction has not started yet',
          );
        }
        
        if (now.isAfter(endTime)) {
          return OperationResult(
            success: false,
            message: 'Auction has already ended',
          );
        }
        
        // Check if bid is higher than current highest bid
        final currentHighestBid = auction['highestBid'];
        double currentBidDouble = 0.0;
        
        if (currentHighestBid is BigInt) {
          currentBidDouble = currentHighestBid.toDouble() / 1e18;  // Convert from wei to ETH
        } else if (currentHighestBid is double) {
          currentBidDouble = currentHighestBid;
        } else if (currentHighestBid != null) {
          // Try to parse as double if it's another type
          currentBidDouble = double.tryParse(currentHighestBid.toString()) ?? 0.0;
        }
        
        if (amount <= currentBidDouble) {
          return OperationResult(
            success: false,
            message: 'Bid must be higher than current highest bid of $currentBidDouble ETH',
          );
        }
        
        // Update the auction
        auction['highestBid'] = amount;
        auction['highestBidder'] = '0xMockBidder${DateTime.now().millisecondsSinceEpoch}';
        
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult(
          success: true,
          data: amount,
          message: 'Bid placed successfully (Mock)',
        );
      } else {
        // Call the real implementation
        await _placeBidReal(deviceId, amount);
        
        // For real implementation, we would fetch the updated auction details
        // but for now, just return a success message
        return OperationResult(
          success: true,
          data: amount,
          message: 'Bid transaction submitted',
        );
      }
    } catch (e) {
      _log('Error placing bid: $e', error: e);
      return OperationResult(
        success: false,
        message: 'Failed to place bid: ${e.toString()}',
      );
    }
  }
  
  // Finalize an auction
  Future<OperationResult> finalizeAuctionNew({required String deviceId}) async {
    _log('Finalizing auction for device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult(
            success: false,
            message: 'Auction not found for device: $deviceId',
          );
        }
        
        final auction = _activeAuctions[deviceId]!;
        final now = DateTime.now();
        final endTime = DateTime.fromMillisecondsSinceEpoch(
            (auction['endTimeBigInt'] as BigInt).toInt() * 1000);
        
        // Check if auction has ended
        if (now.isBefore(endTime)) {
          return OperationResult(
            success: false,
            message: 'Auction has not ended yet',
          );
        }
        
        // Update the auction
        auction['active'] = false;
        auction['finalized'] = true;
        auction['isActive'] = false;
        auction['isFinalized'] = true;
        
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult(
          success: true,
          data: true,
          message: 'Auction finalized successfully (Mock)',
        );
      } else {
        // Call the real implementation
        await _finalizeAuctionReal(deviceId);
        
        // For real implementation, we would fetch the updated auction details
        // but for now, just return a success message
        return OperationResult(
          success: true,
          data: true,
          message: 'Finalization transaction submitted',
        );
      }
    } catch (e) {
      _log('Error finalizing auction: $e', error: e);
      return OperationResult(
        success: false,
        message: 'Failed to finalize auction: ${e.toString()}',
      );
    }
  }
  
  /// Cancel an auction (only available to the owner with no bids)
  Future<OperationResult> cancelAuction({required String deviceId}) async {
    _log('Canceling auction for device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult(
            success: false,
            message: 'Auction not found for device: $deviceId',
          );
        }
        
        // Check if the caller is the owner
        final currentAddress = this.currentAddress?.toLowerCase() ?? '';
        final owner = _activeAuctions[deviceId]!['owner'].toString().toLowerCase();
        
        if (currentAddress != owner) {
          return OperationResult(
            success: false,
            message: 'Only the owner can cancel an auction',
          );
        }
        
        // Check if there are no bids
        final highestBid = _activeAuctions[deviceId]!['highestBid'] as double;
        if (highestBid > 0.0) {
          return OperationResult(
            success: false,
            message: 'Cannot cancel an auction with active bids',
          );
        }
        
        // Cancel the auction
        _activeAuctions[deviceId]!['active'] = false;
        _activeAuctions[deviceId]!['finalized'] = true;
        _activeAuctions[deviceId]!['isActive'] = false;
        _activeAuctions[deviceId]!['isFinalized'] = true;
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult(
          success: true,
          data: true,
          message: 'Auction canceled successfully (Mock)',
        );
      } else {
        // In a real implementation, this would call the contract method
        // For now, we'll just return an error
        return OperationResult(
          success: false,
          message: 'Cancel auction not implemented for blockchain',
        );
      }
    } catch (e) {
      _log('Error canceling auction: $e', error: e);
      return OperationResult(
        success: false,
        message: 'Failed to cancel auction: ${e.toString()}',
      );
    }
  }
  
  /// Checks the current blockchain network status
  /// Returns a map with network information or error details
  Future<Map<String, dynamic>> checkNetworkStatus() async {
    final Map<String, dynamic> result = {
      'timestamp': DateTime.now().toString(),
      'mockMode': _mockMode,
    };
    
    try {
      // First check if Ethereum is supported by the browser
      if (!Ethereum.isSupported) {
        _log('Ethereum is not supported by this browser');
        result['supported'] = false;
        result['message'] = 'Ethereum is not supported by this browser';
        return result;
      }
      
      _log('Ethereum is supported, checking if ethereum object exists');
      
      // Then check if the ethereum object exists
      if (Ethereum.ethereum == null) {
        _log('Ethereum object not found, using JsonRpcProvider');
        result['supported'] = true;
        result['message'] = 'Using direct RPC connection (no wallet)';
        result['providerType'] = 'JsonRpcProvider';
        result['rpcUrl'] = getRpcUrl();
        
        // Check if we can connect to the RPC endpoint
        try {
          final provider = JsonRpcProvider(getRpcUrl());
          final network = await provider.getNetwork();
          result['connected'] = true;
          result['chainId'] = network.chainId;
          result['networkName'] = network.name;
          result['blockNumber'] = await provider.getBlockNumber();
          return result;
        } catch (e) {
          _log('Failed to connect to RPC endpoint:', error: e);
          result['connected'] = false;
          result['message'] = 'Failed to connect to RPC endpoint: $e';
          return result;
        }
      }
      
      _log('Ethereum object exists, checking if it has MetaMask capabilities');
      
      // Since we can't directly check isMetaMask property, we'll assume
      // that if ethereum exists, it's available for our purposes
      result['supported'] = true;
      
      // Check if MetaMask is connected
      final isMetaMaskConnectedObj = Ethereum.ethereum != null ? Ethereum.ethereum!.isConnected : false;
      final bool isMetaMaskConnected = isMetaMaskConnectedObj is bool ? isMetaMaskConnectedObj : false;
      result['connected'] = isMetaMaskConnected;
      
      if (!isMetaMaskConnected) {
        result['message'] = 'MetaMask is not connected';
        return result;
      }
      
      // Get chain ID
      try {
        final chainId = await Ethereum.ethereum!.getChainId();
        result['chainId'] = chainId;
        
        // Determine network name based on chain ID
        switch (chainId) {
          case 1:
            result['networkName'] = 'Ethereum Mainnet';
            break;
          case 3:
            result['networkName'] = 'Ropsten Testnet';
            break;
          case 4:
            result['networkName'] = 'Rinkeby Testnet';
            break;
          case 5:
            result['networkName'] = 'Goerli Testnet';
            break;
          case 42:
            result['networkName'] = 'Kovan Testnet';
            break;
          case 31337:
            result['networkName'] = 'Hardhat Local';
            break;
          case 1337:
            result['networkName'] = 'Ganache Local';
            break;
          default:
            result['networkName'] = 'Unknown Network';
        }
        
        // Get current account
        if (_currentAddress != null) {
          result['account'] = _currentAddress;
        } else {
          try {
            final accounts = await Ethereum.ethereum!.getAccounts();
            if (accounts.isNotEmpty) {
              result['account'] = accounts[0];
            } else {
              result['account'] = 'No account connected';
            }
          } catch (e) {
            result['account'] = 'Error getting account';
          }
        }
        
        // Check if contract is initialized
        result['contractInitialized'] = _isContractInitialized;
        if (_contract != null) {
          result['contractAddress'] = _contract!.address;
        }
        
        // Get block number
        if (_provider != null) {
          try {
            if (_provider is Web3Provider) {
              final blockNumber = await (_provider as Web3Provider).getBlockNumber();
              result['blockNumber'] = blockNumber;
            } else if (_provider is JsonRpcProvider) {
              final blockNumber = await (_provider as JsonRpcProvider).getBlockNumber();
              result['blockNumber'] = blockNumber;
            }
          } catch (e) {
            result['blockNumber'] = 'Error getting block number';
          }
        }
        
        return result;
      } catch (e) {
        _log('Error checking network status:', error: e);
        result['error'] = e.toString();
        return result;
      }
    } catch (e) {
      result['error'] = 'Failed to check network status: ${e.toString()}';
      return result;
    }
  }

  Future<void> _createAuctionReal({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minBidEth,
  }) async {
    _log('Creating auction for device: $deviceId, name: $deviceId');
    
    try {
      if (_contract == null) {
        _log('Contract not initialized');
        throw Exception('Contract not initialized');
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = _stringToBytes32(deviceId);
      _log('Converted deviceId to bytes32: $bytes32DeviceId');
      
      // Convert start and end times to Unix timestamps (seconds since epoch)
      final startTimestamp = BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000);
      final durationSeconds = BigInt.from(duration.inSeconds);
      
      // Convert ETH to wei
      final minBidWei = _toWei(minBidEth);
      
      _log('Creating auction with parameters: deviceId: $deviceId (bytes32: $bytes32DeviceId), start time: $startTime, end time: ${startTime.add(duration)}, min bid: $minBidEth ETH (${minBidWei.toString()} wei)');
      
      // Call the contract method
      final transaction = await _contract!.send(
        'createAuction',
        [bytes32DeviceId, startTimestamp, durationSeconds, minBidWei],
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      _log('Transaction mined: ${receipt.toString()}');
      
      // Refresh auctions after creation
      await _refreshAuctions();
    } catch (e) {
      _log('Error creating auction:', error: e);
      rethrow;
    }
  }

  Future<void> _refreshAuctions() async {
    await loadActiveAuctions();
  }

  /// Helper method to convert ETH to wei
  BigInt _toWei(double ethAmount) {
    // 1 ETH = 10^18 wei
    return BigInt.from(ethAmount * 1e18);
  }

  void initializeWithSettings(SettingsService settingsService) {
    _settingsService = settingsService;
    _mockMode = settingsService.getUseMockBlockchain();
    notifyListeners();
  }
  
  String getRpcUrl() {
    return _settingsService?.getRpcUrl() ?? _localRpcUrl;
  }
  
  String getContractAddress() {
    return _settingsService?.getContractAddress() ?? DADIAuction.address;
  }

  // Simulate the full auction lifecycle in mock mode
  Future<OperationResult> simulateAuctionLifecycle({
    required String deviceId,
    required Duration auctionDuration,
    required double startingBid,
    required int numberOfBids,
  }) async {
    _log('Simulating full auction lifecycle for device: $deviceId');
    
    if (!isMockMode) {
      return OperationResult(
        success: false,
        message: 'Auction lifecycle simulation is only available in mock mode',
      );
    }
    
    try {
      // Step 1: Create the auction
      final now = DateTime.now();
      final startTime = now;
      final endTime = now.add(auctionDuration);
      
      _log('Creating mock auction starting at $startTime and ending at $endTime');
      
      // Create the auction
      final createResult = await createAuction(
        deviceId: deviceId,
        startTime: startTime,
        duration: auctionDuration.inHours,
        minimumBid: startingBid,
      );
      
      if (!createResult.success) {
        return OperationResult(
          success: false,
          message: 'Failed to create auction: ${createResult.message}',
        );
      }
      
      _log('Auction created successfully');
      
      // Step 2: Simulate bidding
      double currentBid = startingBid;
      final bidHistory = <Map<String, dynamic>>[];
      
      for (int i = 0; i < numberOfBids; i++) {
        // Increase bid by a random amount between 5% and 15%
        final bidIncrease = currentBid * (0.05 + (0.1 * (i / numberOfBids)));
        currentBid += bidIncrease;
        
        _log('Placing bid #${i+1}: $currentBid ETH');
        
        // Place the bid
        final bidResult = await placeBidNew(
          deviceId: deviceId,
          amount: currentBid,
        );
        
        if (!bidResult.success) {
          _log('Bid failed: ${bidResult.message}');
          continue;
        }
        
        // Record the bid
        bidHistory.add({
          'bidder': '0xMockBidder${DateTime.now().millisecondsSinceEpoch}',
          'amount': currentBid,
          'timestamp': DateTime.now(),
        });
        
        // Add a small delay between bids
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _log('Completed ${bidHistory.length} bids');
      
      // Step 3: Fast-forward time to end the auction
      // We'll modify the auction's end time to be in the past
      if (_activeAuctions.containsKey(deviceId)) {
        final auction = _activeAuctions[deviceId]!;
        final pastEndTime = DateTime.now().subtract(const Duration(minutes: 1));
        auction['endTime'] = pastEndTime.toIso8601String();  // Always use string for consistency
        _log('Fast-forwarded auction end time to $pastEndTime');
      }
      
      // Step 4: Finalize the auction
      _log('Finalizing auction');
      final finalizeResult = await finalizeAuctionNew(deviceId: deviceId);
      
      if (!finalizeResult.success) {
        return OperationResult(
          success: false,
          message: 'Failed to finalize auction: ${finalizeResult.message}',
        );
      }
      
      _log('Auction finalized successfully');
      
      // Step 5: Return the simulation results
      final simulationResults = {
        'deviceId': deviceId,
        'startTime': startTime,
        'endTime': endTime,
        'startingBid': startingBid,
        'finalBid': currentBid,
        'numberOfBids': bidHistory.length,
        'bidHistory': bidHistory,
        'finalized': true,
        'winner': bidHistory.isNotEmpty ? bidHistory.last['bidder'] : null,
      };
      
      return OperationResult(
        success: true,
        data: simulationResults,
        message: 'Auction lifecycle simulation completed successfully',
      );
    } catch (e) {
      _log('Error simulating auction lifecycle: $e', error: e);
      return OperationResult(
        success: false,
        message: 'Failed to simulate auction lifecycle: ${e.toString()}',
      );
    }
  }

  Future<bool> simulateAuctionLifecycleNew(String deviceId) async {
    if (!isMockMode) {
      _log('Auction lifecycle simulation is only available in mock mode');
      return false;
    }
    
    if (!_activeAuctions.containsKey(deviceId)) {
      _log('Auction not found: $deviceId');
      return false;
    }
    
    try {
      final auction = _activeAuctions[deviceId]!;
      
      // Check if auction is already finalized
      if (auction['finalized'] == true) {
        _log('Auction is already finalized');
        return false;
      }
      
      // Fast-forward time to end the auction if it's not already ended
      final now = DateTime.now();
      final endTimeUnix = (auction['endTimeBigInt'] as BigInt).toInt();
      final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeUnix * 1000);
      
      if (endTime.isAfter(now)) {
        _log('Fast-forwarding auction end time to the past');
        final pastEndTime = now.subtract(const Duration(minutes: 1));
        auction['endTime'] = pastEndTime.toIso8601String();  // Always use string for consistency
      }
      
      // Finalize the auction
      final result = await finalizeAuctionNew(deviceId: deviceId);
      
      if (result.success) {
        _log('Auction finalized successfully');
        Future.microtask(() {
          notifyListeners();
        });
        return true;
      } else {
        _log('Failed to finalize auction: ${result.message}');
        return false;
      }
    } catch (e) {
      _log('Error simulating auction lifecycle: $e', error: e);
      return false;
    }
  }

  // Creates a test auction with a preset future time
  Future<bool> createTestAuctionWithPresetTime() async {
    if (!isMockMode) {
      _log('Enabling mock mode for test auction');
      enableMockMode();
    }
    
    try {
      _log('Creating test auction with preset future time');
      
      // Use a fixed future date for testing
      final DateTime testStartTime = DateTime(2025, 5, 1, 10, 0); // May 1st, 2025, 10:00 AM
      final String testDeviceId = 'test-device-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create 6 sequential 5-minute sessions
      final int sessionCount = 6;
      final int sessionDurationMinutes = 5;
      
      for (int i = 0; i < sessionCount; i++) {
        final sessionStart = testStartTime.add(Duration(minutes: i * sessionDurationMinutes));
        final sessionEnd = sessionStart.add(Duration(minutes: sessionDurationMinutes));
        final sessionId = '$testDeviceId-session-$i';
        
        _activeAuctions[sessionId] = {
          'owner': _currentAddress ?? '0xTestOwner123456789',
          'startTime': sessionStart.toIso8601String(),
          'endTime': sessionEnd.toIso8601String(),
          'minimumBid': 0.1,
          'highestBid': i == 2 ? 0.35 : (i == 4 ? 0.4 : 0.1),
          'highestBidder': '0x0000000000000000000000000000000000000000',
          'active': true,
          'finalized': false,
          'isUserCreated': false,
        };
        
        _log('Created test auction session: $sessionId from ${sessionStart.toString()} to ${sessionEnd.toString()}');
      }
      
      _log('Test auction with preset time created successfully');
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error creating test auction with preset time:', error: e);
      return false;
    }
  }

  /// Create a single test auction with the exact same structure as other test auctions
  Future<bool> createSingleTestAuction() async {
    _log('Creating a single test auction with verified structure');
    
    if (!isMockMode) {
      _log('Enabling mock mode for test auction');
      enableMockMode();
    }
    
    try {
      final DateTime now = DateTime.now();
      final DateTime startTime = now;
      final DateTime endTime = now.add(const Duration(minutes: 15));
      
      // Generate a unique device ID with the same prefix as existing test auctions
      final String deviceId = 'market-device-test-${now.millisecondsSinceEpoch}';
      
      // Follow the exact structure of existing test auctions
      _activeAuctions[deviceId] = {
        'deviceId': deviceId,
        'owner': _currentAddress ?? '0xMockUserAddress123',
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'minimumBid': 0.1,
        'highestBid': 0.0,
        'highestBidder': '0x0000000000000000000000000000000000000000',
        'active': true,
        'isActive': true,
        'finalized': false,
        'isFinalized': false,
        'isUserCreated': true,
      };
      
      _log('Test auction created with structure:');
      _logActiveAuctions('New test auction');
      
      // Make sure to update auction status
      _updateAuctionStatus();
      
      // Force a UI refresh
      notifyListeners();
      
      return true;
    } catch (e) {
      _log('Error creating test auction:', error: e);
      return false;
    }
  }

  /// Calculate the minimum bid increment percentage
  double getBidIncrementPercentage() {
    // Default increment is 5%
    return 0.05;
  }

  /// Calculate the next minimum bid based on current highest bid and increment percentage
  double getNextMinimumBid(double currentHighestBid) {
    // If current highest bid is 0 or very low, start with minimum of 0.1 ETH
    if (currentHighestBid <= 0.001) {
      return 0.1;
    }
    
    final incrementPercentage = getBidIncrementPercentage();
    // Calculate the next bid amount with the percentage increase
    final nextBid = currentHighestBid * (1 + incrementPercentage);
    // Round to 4 decimal places for better UI display
    return double.parse(nextBid.toStringAsFixed(4));
  }

  // Update auction status based on current time
  void _updateAuctionStatus() {
    final now = DateTime.now();
    _log('Updating auction statuses based on current time: $now');
    
    _activeAuctions.forEach((deviceId, auctionData) {
      DateTime endTime;
      if (auctionData['endTimeBigInt'] is BigInt) {
        endTime = DateTime.fromMillisecondsSinceEpoch(
            (auctionData['endTimeBigInt'] as BigInt).toInt() * 1000);
      } else {
        endTime = DateTime.parse(auctionData['endTime'] as String); // Always use string for consistency
        _log('WARNING: Unexpected endTime type for auction $deviceId: ${auctionData['endTime'].runtimeType}');
      }
      
      // Update active status based on current time
      final bool wasActive = auctionData['active'] as bool? ?? true;
      auctionData['active'] = endTime.isAfter(now);
      auctionData['isActive'] = endTime.isAfter(now);
      
      if (wasActive != auctionData['active']) {
        _log('Auction $deviceId status changed: active=$wasActive → ${auctionData['active']}');
      }
    });
    
    _log('Updated auction statuses, total auctions count: ${_activeAuctions.length}');
  }

  Future<void> initialize() async {
    _log('Initializing Web3Service');
    
    if (_mockMode) {
      _log('Mock mode is enabled');
      await _setupMockWallet();
      await loadActiveAuctions();
    }
  }
  
  // Set up a mock wallet address for testing when in mock mode
  Future<void> _setupMockWallet() async {
    if (_currentAddress == null || _currentAddress!.isEmpty) {
      _currentAddress = '0xMockUserAddress123';
      _log('Set up mock wallet with address: $_currentAddress');
      notifyListeners();
    } else {
      _log('Using existing wallet address: $_currentAddress');
    }
  }

  // Synchronously set up a mock wallet address for consistent testing
  void _setupMockWalletSync() {
    if (_currentAddress == null || _currentAddress!.isEmpty) {
      _currentAddress = '0xMockUserAddress123';
      _log('Set up mock wallet address: $_currentAddress');
    } else {
      _log('Using existing wallet address: $_currentAddress');
    }
  }
  
  /// Creates a mock auction for testing purposes
  /// Returns an operation result with the auction ID
  Future<OperationResult<String>> createMockAuction() async {
    if (!_mockMode) {
      return OperationResult<String>(
        success: false,
        message: 'Cannot create mock auction in non-mock mode',
      );
    }
    
    _log('Creating a new mock auction');
    
    final now = DateTime.now();
    final startTime = now;
    final endTime = now.add(const Duration(hours: 1));
    final String deviceId = 'mock-device-${DateTime.now().millisecondsSinceEpoch}';
    
    _activeAuctions[deviceId] = {
      'deviceId': deviceId,
      'owner': _currentAddress ?? '0xMockUserAddress123',
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'minimumBid': 0.01,
      'highestBid': 0.0,
      'highestBidder': '0x0000000000000000000000000000000000000000',
      'active': true,
      'finalized': false,
      'isUserCreated': true,
    };
    
    _log('Created new mock auction with ID: $deviceId');
    notifyListeners();
    
    return OperationResult<String>(
      success: true,
      data: deviceId,
      message: 'Mock auction created successfully',
    );
  }

  /// Force mock mode and create mock auctions
  /// This is especially useful for web environments where mock mode might not be working correctly
  Future<void> forceEnableMockMode() async {
    _log('Forcing mock mode enabled without creating mock auctions');
    _mockMode = true;
    
    // We intentionally DO NOT create any mock auctions here
    // Only preserve any existing user-created auctions
    Map<String, Map<String, dynamic>> userAuctions = {};
    _activeAuctions.forEach((deviceId, auctionData) {
      // Keep auctions that were created by users
      if (auctionData['isUserCreated'] == true) {
        _log('Preserving user-created auction: $deviceId, owner: ${auctionData['owner']}');
        userAuctions[deviceId] = Map.from(auctionData);
      }
    });
    
    // Clear existing auctions
    _activeAuctions.clear();
    
    // Restore user-created auctions
    userAuctions.forEach((deviceId, auctionData) {
      _log('Restoring user-created auction: $deviceId, owner: ${auctionData['owner']}');
      _activeAuctions[deviceId] = auctionData;
    });
    
    _log('Mock mode forced enabled, active auctions: ${_activeAuctions.length}');
    _logActiveAuctions('After force enable');
    
    // Make sure to notify listeners
    Future.microtask(() {
      notifyListeners();
    });
  }

  /// Get all active auctions
  Future<OperationResult> getActiveAuctions() async {
    _log('Getting active auctions');
    
    if (_mockMode) {
      _log('Mock mode enabled, returning mock active auctions');
      
      try {
        await loadActiveAuctions();
        
        _log('Getting active auctions - total count: ${_activeAuctions.length}');
        _log('Keys before filtering: ${_activeAuctions.keys.join(', ')}');
        
        final auctions = _activeAuctions
            .entries
            .where((entry) {
              final data = entry.value;
              // Include if active OR if user created (regardless of active status)
              final isActive = data['active'] ?? data['isActive'] ?? false;
              final isUserCreated = data['isUserCreated'] ?? false;
              final include = isActive || isUserCreated;
              
              _log('Auction ${entry.key}: isActive=$isActive, isUserCreated=$isUserCreated, include=$include');
              
              return include;
            })
            .map((entry) {
              final data = entry.value;
              
              // Extract the start time as DateTime
              DateTime startTime;
              if (data['startTime'] is String) {
                startTime = DateTime.tryParse(data['startTime'] as String) ?? DateTime.now();
              } else if (data['startTime'] is DateTime) {
                startTime = data['startTime'] as DateTime;
              } else {
                startTime = DateTime.now();
              }
              
              // Extract the end time as DateTime
              DateTime endTime;
              if (data['endTime'] is String) {
                endTime = DateTime.tryParse(data['endTime'] as String) ?? DateTime.now().add(const Duration(hours: 1));
              } else if (data['endTime'] is DateTime) {
                endTime = data['endTime'] as DateTime;
              } else {
                endTime = DateTime.now().add(const Duration(hours: 1));
              }
              
              // Extract bid amounts as double
              final minimumBid = data['minimumBid'] is double 
                  ? data['minimumBid'] as double 
                  : (data['minBid'] is double ? data['minBid'] as double : 0.0);
                  
              final highestBid = data['highestBid'] as double? ?? 0.0;
              
              final highestBidder = data['highestBidder'] as String? ?? '0x0000000000000000000000000000000000000000';
              final isActive = data['active'] ?? data['isActive'] ?? true;
              final isFinalized = data['finalized'] ?? data['isFinalized'] ?? false;
              final isUserCreated = data['isUserCreated'] as bool? ?? false;
              
              return {
                'deviceId': entry.key,
                'startTime': startTime.toIso8601String(),
                'endTime': endTime.toIso8601String(),
                'minimumBid': minimumBid,
                'highestBid': highestBid,
                'highestBidder': highestBidder,
                'active': isActive,
                'isActive': isActive,
                'isFinalized': isFinalized,
                'finalized': isFinalized,
                'isUserCreated': isUserCreated,
              };
            })
            .toList();
        
        _log('Returning ${auctions.length} active auctions after filtering');
        return OperationResult(
          success: true,
          data: auctions,
        );
      } catch (e) {
        _log('Error getting active auctions:', error: e);
        return OperationResult(
          success: false,
          message: 'Error getting active auctions: $e',
        );
      }
    }
    
    // If we get here, we're not in mock mode and need to handle real blockchain case
    return OperationResult(
      success: false,
      message: 'Non-mock mode is not fully implemented yet',
    );
  }

  /// Refresh the active auctions list
  Future<void> refreshAuctions() async {
    _log('Refreshing auctions...');
    await loadActiveAuctions(forceRefresh: true);
    _log('After refresh: ${_activeAuctions.length} auctions available');
    _log('Auction keys after refresh: ${_activeAuctions.keys.join(', ')}');
    notifyListeners();
  }

  /// Helper method to place a random bid on an auction
  Future<OperationResult> placeMockBid(String deviceId) async {
    if (!_mockMode) {
      return OperationResult(
        success: false,
        message: 'Mock bidding is only available in mock mode',
      );
    }
    
    if (!_activeAuctions.containsKey(deviceId)) {
      return OperationResult(
        success: false,
        message: 'Auction not found: $deviceId',
      );
    }
    
    try {
      final auction = _activeAuctions[deviceId]!;
      
      // Get current highest bid
      final highestBid = auction['highestBid'];
      double currentBidDouble = 0.0;
      
      if (highestBid is BigInt) {
        currentBidDouble = highestBid.toDouble() / 1e18;  // Convert from wei to ETH
      } else if (highestBid is double) {
        currentBidDouble = highestBid;
      } else if (highestBid != null) {
        // Try to parse as double if it's another type
        currentBidDouble = double.tryParse(highestBid.toString()) ?? 0.0;
      }
      
      // Calculate a new bid that's 10-20% higher
      final bidIncrease = currentBidDouble * (0.1 + (0.1 * (DateTime.now().millisecond / 1000)));
      final newBid = currentBidDouble + bidIncrease;
      
      _log('Placing mock bid of $newBid ETH on device: $deviceId');
      
      // Place the bid
      final result = await placeBidNew(
        deviceId: deviceId,
        amount: newBid,
      );
      
      return result;
    } catch (e) {
      _log('Error placing mock bid: $e', error: e);
      return OperationResult(
        success: false,
        message: 'Failed to place mock bid: ${e.toString()}',
      );
    }
  }
}
