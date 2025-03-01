import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dadi/services/meta_transaction_service.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

/// Mock implementation of MetaTransactionService for testing
class MockMetaTransactionService extends MetaTransactionService {
  final bool delayInitialization;
  final bool simulateFailures;
  final Map<String, int> _nonces = {};
  final WalletServiceInterface _mockWalletService;
  final TransactionWebSocketService? _mockWebSocketService;
  
  /// Constructor
  MockMetaTransactionService({
    this.delayInitialization = false,
    this.simulateFailures = false,
    required WalletServiceInterface walletService,
    TransactionWebSocketService? webSocketService,
  }) : _mockWalletService = walletService,
       _mockWebSocketService = webSocketService,
       super(
         relayerUrl: 'https://mock-relayer.example.com',
         walletService: walletService,
         webSocketService: webSocketService,
       );
  
  @override
  TransactionWebSocketService? get webSocketService => _mockWebSocketService;
  
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
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (delayInitialization) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    }
    
    if (simulateFailures && Random().nextDouble() < 0.8) {
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
    
    // Simulate transaction status updates if callback is provided
    if (onStatusUpdate != null) {
      // Simulate submitted status immediately
      onStatusUpdate(TransactionStatusUpdate(
        txHash: txHash,
        status: TransactionStatus.submitted,
      ));
      
      // Schedule processing status after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        onStatusUpdate(TransactionStatusUpdate(
          txHash: txHash,
          status: TransactionStatus.processing,
        ));
      });
      
      // Schedule confirmed status after a longer delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (simulateFailures && Random().nextDouble() < 0.1) {
          onStatusUpdate(TransactionStatusUpdate(
            txHash: txHash,
            status: TransactionStatus.failed,
            errorMessage: 'Simulated transaction failure',
          ));
        } else {
          onStatusUpdate(TransactionStatusUpdate(
            txHash: txHash,
            status: TransactionStatus.confirmed,
            blockNumber: 12345 + Random().nextInt(1000),
            confirmations: 1 + Random().nextInt(5),
            gasUsed: 21000 + Random().nextInt(50000),
          ));
        }
      });
    }
    
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
  
  @override
  Future<String?> getUserAddress() async {
    return _mockWalletService.currentAddress;
  }
}
