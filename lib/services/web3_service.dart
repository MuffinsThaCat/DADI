      import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_web3/flutter_web3.dart';
import '../contracts/dadi_auction.dart';

class Web3Service extends ChangeNotifier {
  static final Web3Service _instance = Web3Service._internal();
  
  factory Web3Service() => _instance;
  
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
  
  // RPC URL for local Hardhat node
  final String _localRpcUrl = 'http://localhost:8087';
  
  // Mock mode for testing without blockchain
  bool _mockMode = false; // Default to real blockchain connection
  bool get isMockMode => _mockMode;
  set isMockMode(bool value) {
    _mockMode = value;
    notifyListeners();
  }

  // Check if contract is initialized
  bool get isContractInitialized => _isContractInitialized || _mockMode;
  
  // Initialize mock data when in mock mode
  void _initializeMockData() {
    if (isMockMode) {
      _log('Initializing mock auction data');
      
      // Clear existing mock data
      _activeAuctions.clear();
      
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
      
      _log('Loaded ${_activeAuctions.length} mock auctions');
      notifyListeners();
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
        
        if (ethereum != null) {
          _log('Ethereum provider is available');
          _log('Provider type: ${ethereum.runtimeType}');
          
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
            ethereum!.getChainId().then((chainId) {
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
      _log('Checking direct RPC connection to $_localRpcUrl...');
      
      try {
        final jsonRpcProvider = JsonRpcProvider(_localRpcUrl);
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
      if (ethereum == null) {
        _log('Ethereum provider not available, falling back to local RPC');
        
        try {
          _log('Creating JsonRpcProvider with URL: $_localRpcUrl');
          _provider = JsonRpcProvider(_localRpcUrl);
          _log('JsonRpcProvider created successfully');
          
          // Test the provider by getting the network
          try {
            final network = await _provider!.getNetwork();
            _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
          } catch (e) {
            _log('Error getting network from provider:', error: e);
            return false;
          }
        } catch (e) {
          _log('Error creating JsonRpcProvider:', error: e);
          return false;
        }
      } else {
        // Connect to ethereum
        try {
          _log('Ethereum provider available, requesting accounts...');
          final accs = await ethereum!.requestAccount();
          if (accs.isEmpty) {
            _log('No accounts returned from wallet');
            return false;
          }
          
          _currentAddress = accs.first;
          _log('Connected to wallet with address: $_currentAddress');
          
          // Initialize provider
          _log('Creating Web3Provider from ethereum');
          _provider = Web3Provider(ethereum!);
          _log('Web3Provider created successfully');
          
          // Test the provider by getting the network
          try {
            final network = await _provider!.getNetwork();
            _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
          } catch (e) {
            _log('Error getting network from Web3Provider:', error: e);
            return false;
          }
        } catch (e) {
          _log('Failed to connect to wallet:', error: e);
          return false;
        }
      }
      
      // Initialize contract
      _log('Initializing contract...');
      final contractInitialized = await initializeContract();
      
      if (contractInitialized) {
        _log('Contract initialized successfully');
      } else {
        _log('Failed to initialize contract');
        return false;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _log('Error connecting to Web3:', error: e);
      return false;
    }
  }

  // Force connection using JsonRpcProvider directly
  Future<bool> connectWithJsonRpc() async {
    if (_mockMode) {
      _log('Mock mode enabled, skipping real connection');
      return true;
    }

    try {
      _log('Connecting directly with JsonRpcProvider to $_localRpcUrl');
      
      try {
        // Create JsonRpcProvider
        _log('Creating JsonRpcProvider');
        _provider = JsonRpcProvider(_localRpcUrl);
        _log('JsonRpcProvider created');
        
        // Test the provider by getting the network
        try {
          final network = await _provider!.getNetwork();
          _log('Successfully connected to network: ${network.name}, chainId: ${network.chainId}');
        } catch (e) {
          _log('Error getting network from JsonRpcProvider:', error: e);
          return false;
        }
        
        // Initialize contract
        _log('Initializing contract with JsonRpcProvider...');
        final success = await initializeContract();
        
        if (success) {
          _log('Contract initialized successfully with JsonRpcProvider');
          // Set a dummy address for testing
          _currentAddress = '0xJsonRpcProviderAddress';
        } else {
          _log('Failed to initialize contract with JsonRpcProvider');
          return false;
        }
        
        notifyListeners();
        return true;
      } catch (e) {
        _log('Error creating or using JsonRpcProvider:', error: e);
        return false;
      }
    } catch (e) {
      _log('Error connecting with JsonRpcProvider:', error: e);
      return false;
    }
  }

  Future<bool> initializeContract() async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating contract initialization');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      notifyListeners();
      return true;
    }

    try {
      _log('Initializing contract...');
      
      if (_provider == null) {
        _log('Provider not initialized');
        return false;
      }
      
      _log('Provider type: ${_provider.runtimeType}');
      
      try {
        // Get the network information
        final network = await _provider!.getNetwork();
        _log('Connected to network: ${network.name}, chainId: ${network.chainId}');
      } catch (e) {
        _log('Error getting network information:', error: e);
      }
      
      try {
        // Create contract instance
        _log('Creating contract instance with address: ${DADIAuction.address}');
        _contract = Contract(
          DADIAuction.address,
          DADIAuction.abi,
          _provider!,
        );
        _log('Contract instance created successfully');
        
        // Try to call a simple view function to verify contract connection
        try {
          _log('Testing contract connection...');
          final result = await _contract!.call('owner');
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
    if (_mockMode) {
      _log('Mock mode enabled, loading mock auctions');
      
      // Clear existing mock data and reinitialize
      _activeAuctions.clear();
      
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
      
      _log('Loaded ${_activeAuctions.length} mock auctions');
      notifyListeners();
      return;
    }
    
    try {
      if (_contract == null) {
        _log('Contract not initialized, cannot load auctions');
        return;
      }
      
      _log('Fetching auctions from contract...');
      
      // Clear existing auctions
      _activeAuctions.clear();
      
      try {
        // Get auction count
        final auctionCount = await _contract!.call('getAuctionCount');
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
              final auctionData = await _contract!.call('getAuction', [deviceId]);
              
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
      
      notifyListeners();
    } catch (e) {
      _log('Error loading auctions:', error: e);
      throw Exception('Failed to load auctions: $e');
    }
  }

  /// Convert bytes32 to string
  String _bytesToString(dynamic bytes32) {
    if (bytes32 is String) {
      return bytes32;
    }
    
    try {
      // Remove '0x' prefix if present
      String hexString = bytes32.toString();
      if (hexString.startsWith('0x')) {
        hexString = hexString.substring(2);
      }
      
      // Convert hex to bytes
      final List<int> bytes = [];
      for (int i = 0; i < hexString.length; i += 2) {
        if (i + 2 <= hexString.length) {
          final hexPair = hexString.substring(i, i + 2);
          final byte = int.parse(hexPair, radix: 16);
          // Stop at the first null byte
          if (byte == 0) break;
          bytes.add(byte);
        }
      }
      
      // Convert bytes to string
      return utf8.decode(bytes);
    } catch (e) {
      _log('Error converting bytes32 to string:', error: e);
      return bytes32.toString();
    }
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
      
      notifyListeners();
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
      if (receipt.status == BigInt.from(1)) {
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
      
      notifyListeners();
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
      if (receipt.status == BigInt.from(1)) {
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
      final count = await _contract!.call('getAuctionCount');
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
    
    notifyListeners();
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
        _mockMode = true;
        return false;
      }
    } else {
      // If switching to mock mode, load mock auctions
      await loadActiveAuctions();
      return true;
    }
  }
  
  /// Check if MetaMask is installed and available
  Future<bool> isMetaMaskAvailable() async {
    try {
      _log('Checking MetaMask availability');
      
      if (!Ethereum.isSupported) {
        _log('Ethereum is not supported in this browser');
        return false;
      }
      
      if (ethereum == null) {
        _log('Ethereum provider is null');
        return false;
      }
      
      // Try to access ethereum.isMetaMask, but this might not be available
      // Instead, check if we can request accounts, which is a common MetaMask capability
      try {
        _log('Attempting to request accounts to check MetaMask...');
        // We can't directly access isMetaMask property, so we'll check indirectly
        final metaMaskAvailable = await ethereum!.requestAccount();
        _log('Successfully requested accounts: ${metaMaskAvailable.length} accounts found');
        return metaMaskAvailable.isNotEmpty;
      } catch (e) {
        _log('Error requesting accounts:', error: e);
        return false;
      }
    } catch (e) {
      _log('Error checking MetaMask availability:', error: e);
      return false;
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
      if (ethereum == null) {
        _log('Ethereum object not found, using JsonRpcProvider');
        result['supported'] = true;
        result['message'] = 'Using direct RPC connection (no wallet)';
        result['providerType'] = 'JsonRpcProvider';
        result['rpcUrl'] = _localRpcUrl;
        
        // Check if we can connect to the RPC endpoint
        try {
          final provider = JsonRpcProvider(_localRpcUrl);
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
      final isMetaMaskConnectedObj = ethereum != null ? ethereum!.isConnected : false;
      final bool isMetaMaskConnected = isMetaMaskConnectedObj is bool ? isMetaMaskConnectedObj : false;
      result['connected'] = isMetaMaskConnected;
      
      if (!isMetaMaskConnected) {
        result['message'] = 'MetaMask is not connected';
        return result;
      }
      
      // Get chain ID
      try {
        final chainId = await ethereum!.getChainId();
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
            final accounts = await ethereum!.getAccounts();
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

  Future<void> createAuction(String deviceId, DateTime startTime, DateTime endTime, double minBidEth) async {
    _log('Creating auction for device: $deviceId, name: $deviceId');
    
    if (_mockMode) {
      _log('Mock mode enabled, simulating auction creation');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      
      // Convert ETH to wei
      final minBidWei = _toWei(minBidEth);
      
      // Create a new mock auction
      _activeAuctions[deviceId] = {
        'deviceId': deviceId,
        'owner': _currentAddress ?? '0xMockOwner123456789',
        'startTime': startTime,
        'endTime': endTime,
        'minBid': minBidWei,
        'highestBid': BigInt.zero,
        'highestBidder': '0x0000000000000000000000000000000000000000', // No bidder yet
        'active': true,
        'finalized': false,
      };
      
      notifyListeners();
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
      
      // Convert start and end times to Unix timestamps (seconds since epoch)
      final startTimestamp = BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000);
      final duration = BigInt.from((endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch) ~/ 1000);
      
      // Convert ETH to wei
      final minBidWei = _toWei(minBidEth);
      
      _log('Creating auction with parameters: deviceId: $deviceId (bytes32: $bytes32DeviceId), start time: $startTime, end time: $endTime, min bid: $minBidEth ETH (${minBidWei.toString()} wei)');
      
      // Call the contract method
      final transaction = await _contract!.send(
        'createAuction',
        [bytes32DeviceId, startTimestamp, duration, minBidWei],
      );
      
      _log('Transaction sent: ${transaction.hash}');
      
      // Wait for transaction to be mined
      final receipt = await transaction.wait();
      
      // Status 1 means success in Ethereum transactions
      if (receipt.status == BigInt.from(1)) {
        _log('Auction created successfully');
        
        // Refresh auctions list
        await loadActiveAuctions();
      } else {
        _log('Transaction failed');
        throw Exception('Transaction failed');
      }
    } catch (e) {
      _log('Error creating auction:', error: e);
      throw Exception('Failed to create auction: $e');
    }
  }

  // Helper method to convert ETH to wei
  BigInt _toWei(double ethAmount) {
    // 1 ETH = 10^18 wei
    return BigInt.from(ethAmount * 1e18);
  }
}
