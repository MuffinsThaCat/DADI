import 'dart:async';
import 'package:dadi/contracts/meta_transaction_relayer.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

/// Mock implementation of MetaTransactionRelayer for testing
class MockMetaTransactionRelayer implements MetaTransactionRelayer {
  final bool simulateFailures;
  final bool simulateDelays;
  final String _userAddress;
  final StreamController<TransactionStatusUpdate> _transactionStatusController = 
      StreamController<TransactionStatusUpdate>.broadcast();
  final StreamController<TransactionStatusUpdate> _userTransactionStatusController = 
      StreamController<TransactionStatusUpdate>.broadcast();
  
  /// Constructor
  MockMetaTransactionRelayer({
    this.simulateFailures = false,
    this.simulateDelays = false,
    String? userAddress,
  }) : _userAddress = userAddress ?? '0xTestUser123456789';
  
  @override
  Future<String?> getUserAddress() async {
    if (simulateDelays) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _userAddress;
  }
  
  @override
  Future<String> executeFunction({
    required String domainName,
    required String domainVersion,
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String trustedForwarderAddress,
    required String typeName,
    required String typeSuffixData,
    int? gasLimit,
    int? validUntilTime,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (simulateDelays) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (simulateFailures) {
      throw Exception('Simulated relayer failure');
    }
    
    // Generate a mock transaction hash
    final txHash = '0x${List.generate(64, (_) => '0123456789abcdef'[DateTime.now().millisecond % 16]).join('')}';
    
    // Simulate transaction status updates
    if (onStatusUpdate != null) {
      // Submitted
      onStatusUpdate(TransactionStatusUpdate(
        txHash: txHash,
        status: TransactionStatus.submitted,
        timestamp: DateTime.now(),
      ));
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Processing
      onStatusUpdate(TransactionStatusUpdate(
        txHash: txHash,
        status: TransactionStatus.processing,
        timestamp: DateTime.now(),
      ));
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Confirmed
      onStatusUpdate(TransactionStatusUpdate(
        txHash: txHash,
        status: TransactionStatus.confirmed,
        timestamp: DateTime.now(),
        blockNumber: 12345,
      ));
    }
    
    return txHash;
  }
  
  Future<int> getNonce({
    required String userAddress,
    required String trustedForwarderAddress,
  }) async {
    if (simulateDelays) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // Return a random nonce for testing
    return DateTime.now().millisecond;
  }
  
  @override
  Stream<TransactionStatusUpdate> getTransactionStatusStream(String txHash) {
    return _transactionStatusController.stream.where((update) => update.txHash == txHash);
  }
  
  @override
  Stream<TransactionStatusUpdate> getUserTransactionStatusStream(String userAddress) {
    return _userTransactionStatusController.stream;
  }
  
  @override
  Future<bool> checkQuotaAvailable({
    required WalletServiceInterface walletService,
  }) async {
    return true; // Always return true for testing
  }
  
  @override
  Future<BigInt> estimateGasCost({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
  }) async {
    return BigInt.from(100000); // Return a fixed gas estimate for testing
  }
  
  @override
  void unwatchTransaction(String txHash) {
    // No-op in mock implementation
  }
  
  @override
  void unwatchUserTransactions(String userAddress) {
    // No-op in mock implementation
  }
  
  // Helper method to simulate transaction status updates
  void simulateTransactionStatusUpdate(String txHash, TransactionStatus status) {
    final update = TransactionStatusUpdate(
      txHash: txHash,
      status: status,
      timestamp: DateTime.now(),
    );
    _transactionStatusController.add(update);
    _userTransactionStatusController.add(update);
  }
}
