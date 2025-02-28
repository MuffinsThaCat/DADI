import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dadi/services/meta_transaction_service.dart';
import 'package:dadi/services/wallet_service_interface.dart';

/// Mock implementation of MetaTransactionService for testing
class MockMetaTransactionService extends MetaTransactionService {
  final bool delayInitialization;
  final bool simulateFailures;
  final Map<String, int> _nonces = {};
  late final WalletServiceInterface walletService;
  
  /// Constructor
  MockMetaTransactionService({
    this.delayInitialization = false,
    this.simulateFailures = false,
    required WalletServiceInterface walletService,
  }) : super(
         relayerUrl: 'https://mock-relayer.example.com',
         walletService: walletService,
       ) {
    this.walletService = walletService;
  }
  
  @override
  Future<String> executeMetaTransaction({
    required String contractAddress,
    required String functionSignature,
    required List<dynamic> functionParams,
    int? nonce,
  }) async {
    if (delayInitialization) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    }
    
    if (simulateFailures && Random().nextDouble() < 0.2) {
      throw Exception('Simulated relayer failure');
    }
    
    // Get the wallet service from the parent class
    if (!walletService.isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    final userAddress = walletService.currentAddress;
    if (userAddress == null) {
      throw Exception('No wallet address available');
    }
    
    // Get or increment nonce
    final nonceKey = '$userAddress:$contractAddress';
    _nonces[nonceKey] = (_nonces[nonceKey] ?? 0) + 1;
    
    // Generate a mock transaction hash
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(1000000).toString().padLeft(6, '0');
    final txHash = '0x${timestamp.toRadixString(16)}$randomSuffix';
    
    debugPrint('Mock meta-transaction executed: $txHash');
    debugPrint('  Contract: $contractAddress');
    debugPrint('  Function: $functionSignature');
    debugPrint('  Params: $functionParams');
    debugPrint('  Nonce: ${_nonces[nonceKey]}');
    
    return txHash;
  }
  
  // Internal method to get nonce
  Future<int> getNonce(String userAddress, String contractAddress) async {
    if (delayInitialization) {
      await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    }
    
    final nonceKey = '$userAddress:$contractAddress';
    return _nonces[nonceKey] ?? 0;
  }
}
