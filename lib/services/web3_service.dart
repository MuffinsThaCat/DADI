      import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_web3/flutter_web3.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import '../contracts/dadi_auction.g.dart';

class Web3Service extends ChangeNotifier {
  // ignore: avoid_print
  void _log(String message, {Object? error}) {
    if (kIsWeb) {
      // ignore: avoid_print
      print('[Web3Service] $message');
      if (error != null) {
        // ignore: avoid_print
        print('[Web3Service] Error: $error');
      }
    } else {
      developer.log(
        '[Web3Service] $message',
        name: 'Web3Service',
        error: error,
      );
    }
  }

  Web3Provider? _provider;
  String? _currentAddress;
  final Map<String, Map<String, dynamic>> _activeAuctions = {};

  final Map<int, String> _contractAddresses = {
    31337: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // Local Hardhat node
  };

  bool get isConnected => _provider != null && _currentAddress != null;
  String? get currentAddress => _currentAddress;
  Map<String, Map<String, dynamic>> get activeAuctions => _activeAuctions;

  Contract? _contract;

  Future<void> connect() async {
    try {
      if (ethereum == null) {
        throw Exception('MetaMask not found. Please install MetaMask extension.');
      }

      // Switch to Hardhat network first
      try {
        await ethereum!.walletAddChain(
          chainId: 31337,
          chainName: 'Hardhat',
          nativeCurrency: CurrencyParams(
            name: 'Ethereum',
            symbol: 'ETH',
            decimals: 18,
          ),
          rpcUrls: ['http://127.0.0.1:8545'],
        );
      } catch (addError) {
        _log('Chain may already exist: $addError');
      }

      try {
        await ethereum!.walletSwitchChain(31337);
      } catch (switchError) {
        throw Exception('Failed to switch to Hardhat network. Please switch manually in MetaMask.');
      }

      // Now request account access
      final accounts = await ethereum!.requestAccount();
      if (accounts.isEmpty) {
        throw Exception('No accounts found. Please unlock MetaMask and try again.');
      }

      _currentAddress = accounts.first;
      _provider = provider;

      // Verify we're on the right network
      final chainId = await ethereum!.getChainId();
      if (chainId != 31337) {
        throw Exception('Please connect to Hardhat network (Chain ID: 31337)');
      }

      await _setupEventListeners();
      await _loadActiveAuctions();
      notifyListeners();
    } catch (e) {
      _log('Error connecting to wallet: $e');
      _provider = null;
      _currentAddress = null;
      _activeAuctions.clear();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createAuction(
    String deviceId,
    BigInt startTime,
    BigInt duration,
    BigInt minBid,
  ) async {
    if (_provider == null) throw Exception('Not connected');
    
    try {
      _log('Creating auction with parameters:');
      _log('- deviceId: $deviceId');
      _log('- startTime: $startTime (${DateTime.fromMillisecondsSinceEpoch(startTime.toInt() * 1000)})');
      _log('- duration: $duration seconds');
      _log('- minBid: $minBid wei');

      final contractAddress = _contractAddresses[31337]!;
      final signer = _provider!.getSigner();
        
      _log('Creating contract...');
        
      // Create contract with ABI string directly
      final contract = Contract(
        contractAddress,
        DADIAuction.abi,  // Use ABI string directly since it's already an array
        signer,
      );
        
      _log('Contract created');

      // Send the transaction
      final tx = await contract.send(
        'createAuction',
        [deviceId, startTime.toString(), duration.toString(), minBid.toString()]
      );

      _log('Transaction sent with hash: ${tx.hash}');
        
      final receipt = await tx.wait();
      _log('Transaction confirmed in block ${receipt.blockNumber}');
        
      await _loadActiveAuctions();
      _log('Active auctions reloaded');
    } catch (e) {
      _log('Error creating auction:', error: e);
      throw Exception('Failed to create auction. Please check your network connection and ensure you have enough ETH.');
    }
  }

  Future<void> placeBid(String deviceId, BigInt amount) async {
    if (_provider == null) throw Exception('Not connected');
    
    try {
      // Create contract using ethers.js directly for bid placement
      final ethers = js.context['ethers'];
      final contract = js_util.callConstructor(
        js_util.getProperty(ethers, 'Contract'),
        js_util.jsify([
          _contractAddresses[31337]!,
          DADIAuction.abi,
          _provider!.getSigner()
        ])
      );
      
      _log('Placing bid with parameters:');
      _log('- deviceId: $deviceId');
      _log('- amount: $amount wei');
      
      final tx = await js_util.promiseToFuture(
        js_util.callMethod(
          contract,
          'placeBid',
          js_util.jsify([deviceId])
        )
      );
      
      final txHash = js_util.getProperty(tx, 'hash');
      _log('Transaction sent with hash: $txHash');
      
      _log('Waiting for transaction confirmation...');
      final receipt = await js_util.promiseToFuture(
        js_util.callMethod(tx, 'wait', js_util.jsify([]))
      );
      
      final blockNumber = js_util.getProperty(receipt, 'blockNumber');
      _log('Transaction confirmed in block $blockNumber');
      await _loadActiveAuctions();
      _log('Active auctions reloaded');
    } catch (e) {
      _log('Error placing bid:', error: e);
      throw Exception('Failed to place bid. Please check your network connection and ensure you have enough ETH.');
    }
  }

  Future<void> finalizeAuction(String deviceId) async {
    if (_provider == null) throw Exception('Not connected');
    
    try {
      final contract = Contract(
        _contractAddresses[31337]!,
        DADIAuction.abi,
        _provider!.getSigner(),
      );
      
      final tx = await contract.send(
        'finalizeAuction',
        [deviceId]
      );
      await tx.wait();
      await _loadActiveAuctions();
    } catch (e) {
      _log('Error finalizing auction:', error: e);
      throw Exception('Failed to finalize auction.');
    }
  }

  Future<void> _setupEventListeners() async {
    if (_provider == null) return;
    
    final contract = Contract(
      _contractAddresses[31337]!,
      DADIAuction.abi,
      _provider!,
    );

    contract.on('AuctionCreated', (event) {
      _log('AuctionCreated event received');
      _loadActiveAuctions();
    });
  }

  Future<void> _loadActiveAuctions() async {
    if (_provider == null) return;
    
    try {
      // Create contract instance using Web3Provider directly
      final signer = _provider!.getSigner();
      final contract = Contract(
        _contractAddresses[31337]!,
        DADIAuction.abi,
        signer,
      );

      // Test auction for development
      const testDeviceId = '0x3b34058431e9f2d6cb131c2112fdd84675f01302266282003797c20cf29e04fc';
      try {
        // Call auctions mapping using Contract.call
        final result = await contract.call(
          'auctions',
          [testDeviceId],
        );
        
        if (result != null) {
          _activeAuctions[testDeviceId] = {
            'deviceOwner': result[0],
            'startTime': BigInt.parse(result[1].toString()),
            'duration': BigInt.parse(result[2].toString()),
            'minBid': BigInt.parse(result[3].toString()),
            'highestBidder': result[4],
            'highestBid': BigInt.parse(result[5].toString()),
            'finalized': result[6],
          };
          _log('Successfully loaded test auction');
        }
      } catch (e) {
        _log('Error loading test auction:', error: e);
      }
      
      notifyListeners();
    } catch (e) {
      _log('Error loading auctions:', error: e);
    }
  }

  Future<void> disconnect() async {
    _provider = null;
    _currentAddress = null;
    _activeAuctions.clear();
    notifyListeners();
  }
}
