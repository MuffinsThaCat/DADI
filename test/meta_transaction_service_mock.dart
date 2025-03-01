import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dadi/services/meta_transaction_service.dart';
import 'package:dadi/services/wallet_service_interface.dart';

/// Mock implementation of MetaTransactionService for testing
class MockMetaTransactionService extends MetaTransactionService {
  final bool delayInitialization;
  final bool simulateFailures;
  final Map<String, int> _nonces = {};
  final WalletServiceInterface _mockWalletService;
  
  /// Constructor
  MockMetaTransactionService({
    this.delayInitialization = false,
    this.simulateFailures = false,
    required WalletServiceInterface walletService,
  }) : _mockWalletService = walletService,
       super(
         relayerUrl: 'https://mock-relayer.example.com',
         walletService: walletService,
       );
  
  @override
  Future<String> executeMetaTransaction({
    required String trustedForwarderAddress,
    required String contractAddress,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String domainName,
    required String domainVersion,
    String? typeName,
    String? typeSuffixData,
    int? nonce,
    int? gasLimit,
    int? validUntilTime,
  }) async {
    if (delayInitialization) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    }
    
    if (simulateFailures && Random().nextDouble() < 0.2) {
      throw Exception('Simulated relayer failure');
    }
    
    // Check if wallet is unlocked
    if (!_mockWalletService.isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    final userAddress = _mockWalletService.currentAddress;
    if (userAddress == null) {
      throw Exception('No wallet address available');
    }
    
    // Get or increment nonce
    final nonceKey = '$userAddress:$contractAddress';
    final actualNonce = nonce ?? (_nonces[nonceKey] ?? 0);
    _nonces[nonceKey] = actualNonce + 1;
    
    // Generate a mock transaction hash
    final txHash = '0x${List.generate(64, (index) => 
      '0123456789abcdef'[Random().nextInt(16)]).join('')}';
    
    debugPrint('Mock meta-transaction executed: $txHash');
    debugPrint('  Contract: $contractAddress');
    debugPrint('  Function: $functionSignature');
    debugPrint('  Params: $functionParams');
    debugPrint('  Nonce: $actualNonce');
    debugPrint('  Domain: $domainName v$domainVersion');
    debugPrint('  Forwarder: $trustedForwarderAddress');
    
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
