      import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert'; // added import for utf8
import 'package:flutter/foundation.dart';
import 'package:flutter_web3/flutter_web3.dart';
import '../contracts/dadi_auction.dart';

class Web3Service extends ChangeNotifier {
  static final Web3Service _instance = Web3Service._internal();
  
  factory Web3Service() => _instance;
  
  Web3Service._internal();
  
  Web3Provider? _provider;
  String? _currentAddress;
  Contract? _contract;
  final Map<String, Map<String, dynamic>> _activeAuctions = {};
  DateTime _lastAuctionCheck = DateTime(2000); // Initialize with old date
  
  // Mock mode for testing without blockchain
  bool _mockMode = true; // Set to true by default for testing
  bool get mockMode => _mockMode;
  set mockMode(bool value) {
    _mockMode = value;
    notifyListeners();
  }

  void _log(String message, {Object? error}) {
    if (error != null) {
      developer.log('Web3Service: $message', error: error);
    } else {
      developer.log('Web3Service: $message');
    }
  }

  // Getters
  String? get currentAddress => _mockMode ? '0xMockAddress123456789' : _currentAddress;
  Map<String, Map<String, dynamic>> get activeAuctions => _activeAuctions;
  bool get isConnected => _mockMode || (_currentAddress != null && _provider != null);
  bool get isContractInitialized => _mockMode || _contract != null;

  Future<void> connect() async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating connection');
      _currentAddress = '0xMockAddress123456789';
      notifyListeners();
      return;
    }
    
    try {
      _log('Connecting to Web3...');
      
      if (!Ethereum.isSupported) {
        throw Exception('No Web3 provider found. Please install MetaMask.');
      }

      // Request account access
      final accounts = await ethereum!.requestAccount();
      if (accounts.isEmpty) {
        throw Exception('No accounts found. Please connect your wallet.');
      }

      _currentAddress = accounts.first;
      _provider = Web3Provider(ethereum!);
      
      _log('Connected to Web3');
      notifyListeners();
    } catch (e) {
      _log('Error connecting to Web3:', error: e);
      throw Exception('Failed to connect to Web3: $e');
    }
  }

  Future<void> initializeContract() async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating contract initialization');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      notifyListeners();
      return;
    }
    
    try {
      _log('Initializing contract at address: ${DADIAuction.address}');
      
      if (_provider == null) {
        throw Exception('Provider not initialized. Please connect first.');
      }
      
      final signer = _provider!.getSigner();
      _log('Got signer: $signer');
      
      _contract = Contract(
        DADIAuction.address,
        DADIAuction.abi,
        signer,
      );
      
      _log('Contract initialized successfully');
      
      // Test the contract
      await testContract();
      
      notifyListeners();
    } catch (e) {
      _log('Error initializing contract:', error: e);
      _contract = null;
      throw Exception('Failed to initialize contract: $e');
    }
  }

  Future<void> loadActiveAuctions() async {
    if (!isContractInitialized) {
      _log('Contract not initialized');
      return;
    }

    // Prevent checking too frequently (at most once every 10 seconds)
    final now = DateTime.now();
    if (now.difference(_lastAuctionCheck).inSeconds < 10) {
      return;
    }
    _lastAuctionCheck = now;

    try {
      _log('Loading active auctions...');
      _activeAuctions.clear();

      final testDevices = [
        'device1',
        'device2',
        'device3'
      ];

      if (_mockMode) {
        // Add some mock auctions for testing
        _activeAuctions['Mock Device 1'] = {
          'id': 'auction1',
          'owner': '0xMockOwner123456789',
          'endTime': BigInt.from((now.millisecondsSinceEpoch ~/ 1000) + 86400), // 1 day from now
          'minBid': BigInt.from(10000000000000000), // 0.01 ETH
          'highestBidder': '0x0000000000000000000000000000000000000000',
          'highestBid': BigInt.zero,
        };
        _log('Added mock auction for: Mock Device 1');
      } else {
        for (final deviceId in testDevices) {
          try {
            final result = await _contract!.call<List>('auctions', [deviceId]);
            if (result.isNotEmpty) {
              final endTime = result[2] as BigInt;
              final nowBigInt = BigInt.from(now.millisecondsSinceEpoch ~/ 1000);
              
              if (endTime > nowBigInt) {
                _activeAuctions[deviceId] = {
                  'id': result[0],
                  'owner': result[1],
                  'endTime': result[2],
                  'minBid': result[3],
                  'highestBidder': result[4],
                  'highestBid': result[5],
                };
                _log('Found active auction for: $deviceId');
              }
            }
          } catch (e) {
            // Just log a simple message without the full error to reduce console spam
            _log('No active auction for device $deviceId');
          }
        }
      }

      _log('Finished loading auctions');
      notifyListeners();
    } catch (e) {
      _log('Error loading auctions:', error: e);
    }
  }

  Future<void> createAuction(
    String deviceId,
    DateTime startTime,
    DateTime endTime,
    BigInt minBid,
  ) async {
    if (!isContractInitialized) {
      _log('Cannot create auction: Contract is null');
      await initializeContract();
      if (!isContractInitialized) {
        throw Exception('Failed to initialize contract');
      }
    }

    try {
      _log('Creating auction with params:');
      _log('Device ID: $deviceId');
      _log('Start Time: ${startTime.millisecondsSinceEpoch}');
      _log('End Time: ${endTime.millisecondsSinceEpoch}');
      _log('Min Bid: $minBid wei');
      
      if (_mockMode) {
        _log('Mock mode enabled, simulating auction creation');
        await Future.delayed(const Duration(seconds: 1)); // Simulate transaction time
        
        // Add a mock auction
        _activeAuctions[deviceId] = {
          'id': 'auction-${DateTime.now().millisecondsSinceEpoch}',
          'owner': currentAddress,
          'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
          'minBid': minBid,
          'highestBidder': '0x0000000000000000000000000000000000000000',
          'highestBid': BigInt.zero,
        };
        
        _log('Mock auction created successfully');
        notifyListeners();
        return;
      }
      
      // Convert deviceId to bytes32
      final bytes32DeviceId = utf8.encode(deviceId.padRight(32, '\x00'));
      
      // Convert DateTime to Unix timestamp (seconds)
      final startTimeSeconds = BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000);
      final endTimeSeconds = BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000);
      
      _log('Converted params:');
      _log('Device ID (bytes32): $bytes32DeviceId');
      _log('Start Time (seconds): $startTimeSeconds');
      _log('End Time (seconds): $endTimeSeconds');
      
      // Call the contract method
      final tx = await _contract!.send(
        'createAuction',
        [bytes32DeviceId, startTimeSeconds, endTimeSeconds, minBid],
      );
      
      _log('Transaction sent: $tx');
      
      // Wait for transaction to be mined
      final receipt = await tx.wait();
      _log('Transaction mined: ${receipt.transactionHash}');
      
      // Refresh auctions after creating a new one
      await loadActiveAuctions();
      
      return;
    } catch (e) {
      _log('Error creating auction:', error: e);
      throw Exception('Failed to create auction: $e');
    }
  }

  Future<void> placeBid(String deviceId, BigInt amount) async {
    if (!isContractInitialized) {
      _log('Cannot place bid: Contract is null');
      await initializeContract();
      if (!isContractInitialized) {
        throw Exception('Failed to initialize contract');
      }
    }

    try {
      _log('Placing bid on device $deviceId with amount $amount wei');
      
      if (_mockMode) {
        _log('Mock mode enabled, simulating bid placement');
        await Future.delayed(const Duration(seconds: 1)); // Simulate transaction time
        
        // Update the mock auction
        if (_activeAuctions.containsKey(deviceId)) {
          final auction = _activeAuctions[deviceId]!;
          final currentBid = auction['highestBid'] as BigInt;
          
          if (amount > currentBid) {
            auction['highestBid'] = amount;
            auction['highestBidder'] = currentAddress;
            _log('Mock bid placed successfully');
          } else {
            throw Exception('Bid amount must be higher than current bid');
          }
        } else {
          throw Exception('No active auction found for device $deviceId');
        }
        
        notifyListeners();
        return;
      }
      
      // Call the contract method
      final tx = await _contract!.send(
        'placeBid',
        [deviceId],
        TransactionOverride(
          value: amount,
        ),
      );
      
      _log('Transaction sent: $tx');
      
      // Wait for transaction to be mined
      final receipt = await tx.wait();
      _log('Transaction mined: ${receipt.transactionHash}');
      
      // Refresh auctions after placing a bid
      await loadActiveAuctions();
      
      return;
    } catch (e) {
      _log('Error placing bid:', error: e);
      throw Exception('Failed to place bid: $e');
    }
  }

  Future<void> finalizeAuction(String deviceId) async {
    if (!isContractInitialized) {
      _log('Cannot finalize auction: Contract is null');
      await initializeContract();
      if (!isContractInitialized) {
        throw Exception('Failed to initialize contract');
      }
    }

    try {
      _log('Finalizing auction for device $deviceId');
      
      if (_mockMode) {
        _log('Mock mode enabled, simulating auction finalization');
        await Future.delayed(const Duration(seconds: 1)); // Simulate transaction time
        
        // Update the mock auction
        if (_activeAuctions.containsKey(deviceId)) {
          _activeAuctions.remove(deviceId);
          _log('Mock auction finalized successfully');
        } else {
          throw Exception('No active auction found for device $deviceId');
        }
        
        notifyListeners();
        return;
      }
      
      // Call the contract method
      final tx = await _contract!.send(
        'finalizeAuction',
        [deviceId],
      );
      
      _log('Transaction sent: $tx');
      
      // Wait for transaction to be mined
      final receipt = await tx.wait();
      _log('Transaction mined: ${receipt.transactionHash}');
      
      // Refresh auctions after finalizing
      await loadActiveAuctions();
      
      return;
    } catch (e) {
      _log('Error finalizing auction:', error: e);
      throw Exception('Failed to finalize auction: $e');
    }
  }

  Future<bool> testContract() async {
    if (_mockMode) {
      _log('Mock mode enabled, simulating contract test');
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
      _log('Contract test successful. Owner: 0xMockOwner123456789');
      return true;
    }
    
    try {
      _log('Testing contract...');
      
      if (_contract == null) {
        throw Exception('Contract is null');
      }
      
      final owner = await _contract!.call<String>('owner', []);
      _log('Contract test successful. Owner: $owner');
      
      return true;
    } catch (e) {
      _log('Error testing contract:', error: e);
      return false;
    }
  }

  void disconnect() {
    _provider = null;
    _currentAddress = null;
    _contract = null;
    _activeAuctions.clear();
    notifyListeners();
    _log('Disconnected');
  }

  /// Toggle between mock mode and real blockchain mode
  void toggleMockMode() {
    _mockMode = !_mockMode;
    _log('Mock mode ${_mockMode ? 'enabled' : 'disabled'}');
    
    // Re-initialize contract with new mode
    initializeContract();
    
    notifyListeners();
  }
  
  /// Get the current mock mode status
  bool get isMockMode => _mockMode;
}
