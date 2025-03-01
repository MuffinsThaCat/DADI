      import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert'; 
import 'package:flutter/foundation.dart';
import 'flutter_web3.dart';
import '../contracts/dadi_auction.dart';
import '../models/auction.dart';
import '../models/operation_result.dart';
import '../services/settings_service.dart';

class Web3Service extends ChangeNotifier {
  static final Web3Service _instance = Web3Service._internal();
  
  factory Web3Service() => _instance;
  
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
      _log('Initializing mock auction data');
      _log('Current active auctions count: ${_activeAuctions.length}');
      
      // Only initialize if we don't have any auctions yet
      if (_activeAuctions.isEmpty) {
        _log('No existing mock auctions found, creating default mock auctions');
        
        // Get current time for comparison
        final now = DateTime.now();
        
        // Create some mock auctions
        final endTime1 = now.add(const Duration(hours: 2));
        final endTime2 = now.add(const Duration(hours: 5));
        final endTime3 = now.subtract(const Duration(hours: 2)); // This one has ended
        
        // Mock auction 1
        _activeAuctions['device1'] = {
          'deviceId': 'device1',
          'owner': '0xMockOwner123456789',
          'startTime': now.subtract(const Duration(hours: 2)),
          'endTime': BigInt.from(endTime1.millisecondsSinceEpoch ~/ 1000),
          'highestBid': BigInt.from(100),
          'highestBidder': '0xMockBidder123456789',
          'active': true,
          'finalized': false,
        };
        
        // Mock auction 2
        _activeAuctions['device2'] = {
          'deviceId': 'device2',
          'owner': '0xMockOwner987654321',
          'startTime': now.subtract(const Duration(hours: 1)),
          'endTime': BigInt.from(endTime2.millisecondsSinceEpoch ~/ 1000),
          'highestBid': BigInt.from(200),
          'highestBidder': '0xMockBidder987654321',
          'active': true,
          'finalized': false,
        };
        
        // Mock auction 3 (ended)
        _activeAuctions['device3'] = {
          'deviceId': 'device3',
          'owner': '0xMockOwner555555555',
          'startTime': now.subtract(const Duration(days: 2)),
          'endTime': BigInt.from(endTime3.millisecondsSinceEpoch ~/ 1000),
          'highestBid': BigInt.from(300),
          'highestBidder': '0xMockBidder555555555',
          'active': false,
          'finalized': true,
        };
        
        _log('Created ${_activeAuctions.length} default mock auctions');
        notifyListeners();
      } else {
        _log('Using existing ${_activeAuctions.length} mock auctions');
      }
    }
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

  // Getters
  String? get currentAddress => isMockMode ? '0xMockAddress123456789' : _currentAddress;
  
  Map<String, Map<String, dynamic>> get activeAuctions => _activeAuctions;
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

  Future<void> loadActiveAuctions() async {
    _log('loadActiveAuctions called, isMockMode: $isMockMode');
    
    if (_mockMode) {
      _log('Mock mode enabled, loading mock auctions');
      _log('Current active auctions count: ${_activeAuctions.length}');
      _log('Current active auction keys: ${_activeAuctions.keys.join(', ')}');
      
      // If we already have mock auctions, don't reinitialize
      if (_activeAuctions.isNotEmpty) {
        _log('Mock auctions already loaded, skipping initialization');
        Future.microtask(() {
          notifyListeners();
        });
        return;
      }
      
      _log('No mock auctions found, initializing mock data');
      
      // Initialize mock data
      _initializeMockData();
      
      _log('Mock auctions initialized, count: ${_activeAuctions.length}');
      _log('Mock auction keys: ${_activeAuctions.keys.join(', ')}');
      
      Future.microtask(() {
        notifyListeners();
      });
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
                'startTime': startTime,
                'endTime': endTime,
                'minBid': minBid,
                'highestBid': highestBid,
                'highestBidder': highestBidder,
                'active': isActive,
                'finalized': isFinalized,
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
      if (amountWei <= (auction['highestBid'] as BigInt)) {
        throw Exception('Bid amount must be higher than current highest bid');
      }
      
      // Update auction with new bid
      auction['highestBid'] = amountWei;
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

  // Create a new auction
  Future<OperationResult<Auction>> createAuction({
    required String deviceId,
    required DateTime startTime,
    required Duration duration,
    required double minimumBid,
  }) async {
    _log('createAuction called for device: $deviceId, isMockMode: $isMockMode');
    
    try {
      if (isMockMode) {
        _log('Mock mode enabled, creating mock auction');
        final endTime = startTime.add(duration);
        _log('Creating mock auction with endTime: $endTime');
        
        _activeAuctions[deviceId] = {
          'deviceId': deviceId,
          'owner': '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
          'startTime': startTime,
          'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
          'minimumBid': minimumBid,
          'highestBid': BigInt.from(0),
          'highestBidder': '0x0000000000000000000000000000000000000000',
          'active': true,
          'finalized': false,
        };
        
        _log('Added mock auction to _activeAuctions, count: ${_activeAuctions.length}');
        _log('Active auction keys: ${_activeAuctions.keys.join(', ')}');
        
        Future.microtask(() {
          notifyListeners();
        });
        
        final auction = Auction.fromBlockchainData(_activeAuctions[deviceId]!);
        return OperationResult.success(
          data: auction,
          message: 'Auction created successfully (Mock)',
        );
      } else {
        _log('Real mode enabled, creating real auction');
        await _createAuctionReal(
          deviceId: deviceId,
          startTime: startTime,
          duration: duration,
          minBidEth: minimumBid,
        );
        
        _log('Real auction created successfully');
        
        // For real implementation, we would fetch the auction details
        // but for now, just return a success message
        return OperationResult.success(
          message: 'Auction creation transaction submitted',
        );
      }
    } catch (e) {
      _log('Error creating auction: $e', error: e);
      return OperationResult.failure(message: 'Failed to create auction: ${e.toString()}');
    }
  }
  
  /// Get an auction by device ID
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    _log('Getting auction for device: $deviceId');
    
    if (_mockMode) {
      _log('Mock mode enabled, getting mock auction');
      
      if (!_activeAuctions.containsKey(deviceId)) {
        return OperationResult<Auction>(
          success: false,
          message: 'Auction not found',
        );
      }
      
      final data = _activeAuctions[deviceId]!;
      
      final auction = Auction(
        deviceId: data['deviceId'],
        owner: data['owner'],
        startTime: data['startTime'],
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (data['endTime'] as BigInt).toInt() * 1000,
        ),
        minimumBid: data['minimumBid'],
        highestBid: data['highestBid'] != null 
            ? (data['highestBid'] is BigInt 
                ? (data['highestBid'] as BigInt).toDouble() / 1e18 
                : (data['highestBid'] as double))
            : 0.0,
        highestBidder: data['highestBidder'] ?? '0x0000000000000000000000000000000000000000',
        isActive: data['active'] ?? true,
        isFinalized: data['finalized'] ?? false,
      );
      
      return OperationResult<Auction>(
        success: true,
        data: auction,
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
      final result = await _contract!.call('getAuction', [deviceId]) as List<dynamic>;
      
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
  
  // Place a bid on an auction
  Future<OperationResult<double>> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    _log('Placing bid of $amount ETH on device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult.failure(message: 'Auction not found for device: $deviceId');
        }
        
        final auction = _activeAuctions[deviceId]!;
        final now = DateTime.now();
        final startTime = auction['startTime'] is DateTime 
            ? auction['startTime'] as DateTime
            : DateTime.fromMillisecondsSinceEpoch((auction['startTime'] as BigInt).toInt() * 1000);
        
        final endTime = DateTime.fromMillisecondsSinceEpoch(
            (auction['endTime'] as BigInt).toInt() * 1000);
        
        // Check if auction is active
        if (now.isBefore(startTime)) {
          return OperationResult.failure(message: 'Auction has not started yet');
        }
        
        if (now.isAfter(endTime)) {
          return OperationResult.failure(message: 'Auction has already ended');
        }
        
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
        
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult.success(
          data: amount,
          message: 'Bid placed successfully (Mock)',
        );
      } else {
        // Call the real implementation
        await _placeBidReal(deviceId, amount);
        
        // For real implementation, we would fetch the updated auction details
        // but for now, just return a success message
        return OperationResult.success(
          data: amount,
          message: 'Bid transaction submitted',
        );
      }
    } catch (e) {
      _log('Error placing bid: $e', error: e);
      return OperationResult.failure(message: 'Failed to place bid: ${e.toString()}');
    }
  }
  
  // Finalize an auction
  Future<OperationResult<bool>> finalizeAuctionNew({required String deviceId}) async {
    _log('Finalizing auction for device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult.failure(message: 'Auction not found for device: $deviceId');
        }
        
        final auction = _activeAuctions[deviceId]!;
        final now = DateTime.now();
        final endTime = DateTime.fromMillisecondsSinceEpoch(
            (auction['endTime'] as BigInt).toInt() * 1000);
        
        // Check if auction has ended
        if (now.isBefore(endTime)) {
          return OperationResult.failure(message: 'Auction has not ended yet');
        }
        
        // Update the auction
        auction['active'] = false;
        auction['finalized'] = true;
        
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult.success(
          data: true,
          message: 'Auction finalized successfully (Mock)',
        );
      } else {
        // Call the real implementation
        await _finalizeAuctionReal(deviceId);
        
        // For real implementation, we would fetch the updated auction details
        // but for now, just return a success message
        return OperationResult.success(
          data: true,
          message: 'Finalization transaction submitted',
        );
      }
    } catch (e) {
      _log('Error finalizing auction: $e', error: e);
      return OperationResult.failure(message: 'Failed to finalize auction: ${e.toString()}');
    }
  }
  
  // Cancel an auction (only available to the owner with no bids)
  Future<OperationResult<bool>> cancelAuction({required String deviceId}) async {
    _log('Canceling auction for device: $deviceId');
    
    try {
      if (isMockMode) {
        // Mock implementation
        if (!_activeAuctions.containsKey(deviceId)) {
          return OperationResult.failure(message: 'Auction not found for device: $deviceId');
        }
        
        // Check if the caller is the owner
        final currentAddress = this.currentAddress?.toLowerCase() ?? '';
        final owner = _activeAuctions[deviceId]!['owner'].toString().toLowerCase();
        
        if (currentAddress != owner) {
          return OperationResult.failure(message: 'Only the owner can cancel an auction');
        }
        
        // Check if there are no bids
        final highestBid = _activeAuctions[deviceId]!['highestBid'] as BigInt;
        if (highestBid > BigInt.zero) {
          return OperationResult.failure(message: 'Cannot cancel an auction with active bids');
        }
        
        // Cancel the auction
        _activeAuctions[deviceId]!['active'] = false;
        _activeAuctions[deviceId]!['finalized'] = true;
        Future.microtask(() {
          notifyListeners();
        });
        
        return OperationResult.success(
          data: true,
          message: 'Auction canceled successfully (Mock)',
        );
      } else {
        // In a real implementation, this would call the contract method
        // For now, we'll just return an error
        return OperationResult.failure(message: 'Cancel auction not implemented for blockchain');
      }
    } catch (e) {
      _log('Error canceling auction: $e', error: e);
      return OperationResult.failure(message: 'Failed to cancel auction: ${e.toString()}');
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
  Future<OperationResult<Map<String, dynamic>>> simulateAuctionLifecycle({
    required String deviceId,
    required Duration auctionDuration,
    required double startingBid,
    required int numberOfBids,
  }) async {
    _log('Simulating full auction lifecycle for device: $deviceId');
    
    if (!isMockMode) {
      return OperationResult.failure(message: 'Auction lifecycle simulation is only available in mock mode');
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
        duration: auctionDuration,
        minimumBid: startingBid,
      );
      
      if (!createResult.success) {
        return OperationResult.failure(message: 'Failed to create auction: ${createResult.message}');
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
        auction['endTime'] = BigInt.from(pastEndTime.millisecondsSinceEpoch ~/ 1000);
        _log('Fast-forwarded auction end time to $pastEndTime');
      }
      
      // Step 4: Finalize the auction
      _log('Finalizing auction');
      final finalizeResult = await finalizeAuctionNew(deviceId: deviceId);
      
      if (!finalizeResult.success) {
        return OperationResult.failure(message: 'Failed to finalize auction: ${finalizeResult.message}');
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
      
      return OperationResult.success(
        data: simulationResults,
        message: 'Auction lifecycle simulation completed successfully',
      );
    } catch (e) {
      _log('Error simulating auction lifecycle: $e', error: e);
      return OperationResult.failure(message: 'Failed to simulate auction lifecycle: ${e.toString()}');
    }
  }

  // Helper method to simulate the auction lifecycle in mock mode
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
      final endTimeUnix = (auction['endTime'] as BigInt).toInt();
      final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeUnix * 1000);
      
      if (endTime.isAfter(now)) {
        _log('Fast-forwarding auction end time to the past');
        final pastEndTime = now.subtract(const Duration(minutes: 1));
        auction['endTime'] = BigInt.from(pastEndTime.millisecondsSinceEpoch ~/ 1000);
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

  // Helper method to create a mock auction with the given parameters
  Future<OperationResult<String>> createMockAuction({
    String? deviceId,
    Duration duration = const Duration(hours: 2),
    double minimumBid = 0.1,
  }) async {
    _log('createMockAuction called with deviceId: $deviceId, isMockMode: $isMockMode');
    
    if (!isMockMode) {
      _log('Mock auctions can only be created in mock mode');
      return OperationResult.failure(message: 'Mock auctions can only be created in mock mode');
    }
    
    try {
      // Generate a unique device ID if not provided
      final auctionDeviceId = deviceId ?? 'mock-device-${DateTime.now().millisecondsSinceEpoch}';
      _log('Using device ID: $auctionDeviceId');
      
      // Check if an auction already exists for this device
      if (_activeAuctions.containsKey(auctionDeviceId)) {
        _log('An auction already exists for device: $auctionDeviceId');
        return OperationResult.failure(message: 'An auction already exists for device: $auctionDeviceId');
      }
      
      // Create the auction
      final now = DateTime.now();
      final startTime = now;
      final endTime = now.add(duration);
      
      _log('Creating mock auction for device: $auctionDeviceId, start: $startTime, end: $endTime');
      
      final result = await createAuction(
        deviceId: auctionDeviceId,
        startTime: startTime,
        duration: duration,
        minimumBid: minimumBid,
      );
      
      if (result.success) {
        _log('Mock auction created successfully, active auctions: ${_activeAuctions.length}');
        return OperationResult.success(
          data: auctionDeviceId,
          message: 'Mock auction created successfully',
        );
      } else {
        _log('Failed to create mock auction: ${result.message}');
        return OperationResult.failure(message: result.message);
      }
    } catch (e) {
      _log('Error creating mock auction: $e', error: e);
      return OperationResult.failure(message: 'Failed to create mock auction: ${e.toString()}');
    }
  }

  // Helper method to place a random bid on an auction
  Future<OperationResult<double>> placeMockBid(String deviceId) async {
    if (!isMockMode) {
      return OperationResult.failure(message: 'Mock bidding is only available in mock mode');
    }
    
    if (!_activeAuctions.containsKey(deviceId)) {
      return OperationResult.failure(message: 'Auction not found: $deviceId');
    }
    
    try {
      final auction = _activeAuctions[deviceId]!;
      
      // Get current highest bid
      final highestBidWei = auction['highestBid'] as BigInt;
      final highestBidEth = highestBidWei.toDouble() / 1e18;
      
      // Calculate a new bid that's 10-20% higher
      final bidIncrease = highestBidEth * (0.1 + (0.1 * (DateTime.now().millisecond / 1000)));
      final newBid = highestBidEth + bidIncrease;
      
      _log('Placing mock bid of $newBid ETH on device: $deviceId');
      
      // Place the bid
      final result = await placeBidNew(
        deviceId: deviceId,
        amount: newBid,
      );
      
      return result;
    } catch (e) {
      _log('Error placing mock bid: $e', error: e);
      return OperationResult.failure(message: 'Failed to place mock bid: ${e.toString()}');
    }
  }

  /// Force mock mode and create mock auctions
  /// This is especially useful for web environments where mock mode might not be working correctly
  Future<void> forceEnableMockMode() async {
    _log('Forcing mock mode enabled');
    _mockMode = true;
    
    // Clear any existing auctions to start fresh
    _activeAuctions.clear();
    
    // Initialize with default mock auctions
    _initializeMockData();
    
    // Create an additional mock auction with current timestamp
    final deviceId = 'mock-device-${DateTime.now().millisecondsSinceEpoch}';
    _log('Creating additional mock auction with ID: $deviceId');
    
    final now = DateTime.now();
    final endTime = now.add(const Duration(hours: 2));
    
    _activeAuctions[deviceId] = {
      'deviceId': deviceId,
      'owner': '0xMockOwner${DateTime.now().millisecondsSinceEpoch}',
      'startTime': now,
      'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
      'minimumBid': 0.1,
      'highestBid': BigInt.from(0),
      'highestBidder': '0x0000000000000000000000000000000000000000',
      'active': true,
      'finalized': false,
    };
    
    _log('Mock mode forced enabled, active auctions: ${_activeAuctions.length}');
    _log('Active auction keys: ${_activeAuctions.keys.join(', ')}');
    
    // Make sure to notify listeners
    Future.microtask(() {
      notifyListeners();
    });
  }

  /// Get all active auctions
  Future<OperationResult<List<Auction>>> getActiveAuctions() async {
    _log('Getting active auctions');
    
    if (_mockMode) {
      _log('Mock mode enabled, returning mock active auctions');
      
      try {
        // Convert the _activeAuctions map to a list of Auction objects
        final activeAuctions = _activeAuctions.entries
            .where((entry) => entry.value['active'] == true)
            .map((entry) {
              final data = entry.value;
              
              // Handle various data types and null values
              final startTime = data['startTime'] is DateTime 
                  ? data['startTime'] as DateTime
                  : DateTime.now().subtract(const Duration(hours: 1));
              
              final endTimeValue = data['endTime'];
              final endTime = endTimeValue is DateTime 
                  ? endTimeValue 
                  : endTimeValue is BigInt 
                      ? DateTime.fromMillisecondsSinceEpoch((endTimeValue).toInt() * 1000)
                      : endTimeValue is int
                          ? DateTime.fromMillisecondsSinceEpoch(endTimeValue * 1000)
                          : DateTime.now().add(const Duration(hours: 23));
              
              final minimumBidValue = data['minimumBid'];
              final minimumBid = minimumBidValue is double 
                  ? minimumBidValue 
                  : minimumBidValue is BigInt
                      ? minimumBidValue.toDouble() / 1e18
                      : 0.1;
              
              final highestBidValue = data['highestBid'];
              final highestBid = highestBidValue is double 
                  ? highestBidValue 
                  : highestBidValue is BigInt
                      ? highestBidValue.toDouble() / 1e18
                      : 0.0;
              
              final highestBidder = data['highestBidder'] as String? ?? '0x0000000000000000000000000000000000000000';
              final isActive = data['active'] as bool? ?? true;
              final isFinalized = data['finalized'] as bool? ?? false;
              
              return Auction(
                deviceId: data['deviceId'] ?? 'unknown-device',
                owner: data['owner'] ?? '0x0000000000000000000000000000000000000000',
                startTime: startTime,
                endTime: endTime,
                minimumBid: minimumBid,
                highestBid: highestBid,
                highestBidder: highestBidder,
                isActive: isActive,
                isFinalized: isFinalized,
              );
            })
            .toList();
        
        _log('Found ${activeAuctions.length} active mock auctions');
        return OperationResult<List<Auction>>(
          success: true,
          data: activeAuctions,
        );
      } catch (e) {
        _log('Error processing mock auctions: $e');
        // Return empty list instead of failing
        return OperationResult<List<Auction>>(
          success: true,
          data: [],
          message: 'Error processing mock auctions: $e',
        );
      }
    }
    
    try {
      if (_contract == null || _provider == null) {
        return OperationResult<List<Auction>>(
          success: false,
          message: 'Contract or provider not initialized',
        );
      }
      
      // Call getActiveAuctions function
      final result = await _contract!.call('getActiveAuctions', []) as List<dynamic>;
      
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
        if (auctionResult.success && auctionResult.data != null) {
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
}
