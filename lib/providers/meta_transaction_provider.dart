import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/meta_transaction_service.dart';
import '../contracts/meta_transaction_relayer.dart';

/// Status of a meta-transaction
enum MetaTransactionStatus {
  /// Transaction has been submitted to the relayer
  submitted,
  
  /// Transaction is being processed by the relayer
  processing,
  
  /// Transaction has been confirmed on the blockchain
  confirmed,
  
  /// Transaction failed
  failed,
}

/// Represents a meta-transaction with its status and details
class MetaTransaction {
  /// Unique identifier for the transaction
  final String id;
  
  /// Hash of the transaction on the blockchain (if available)
  final String? txHash;
  
  /// Current status of the transaction
  final MetaTransactionStatus status;
  
  /// Error message if the transaction failed
  final String? error;
  
  /// Timestamp when the transaction was created
  final DateTime timestamp;
  
  /// Target contract address
  final String targetContract;
  
  /// Function signature being called
  final String functionSignature;
  
  /// Human-readable description of the transaction
  final String description;

  /// Constructor
  MetaTransaction({
    required this.id,
    this.txHash,
    required this.status,
    this.error,
    required this.timestamp,
    required this.targetContract,
    required this.functionSignature,
    required this.description,
  });

  /// Create a copy of this transaction with updated fields
  MetaTransaction copyWith({
    String? id,
    String? txHash,
    MetaTransactionStatus? status,
    String? error,
    DateTime? timestamp,
    String? targetContract,
    String? functionSignature,
    String? description,
  }) {
    return MetaTransaction(
      id: id ?? this.id,
      txHash: txHash ?? this.txHash,
      status: status ?? this.status,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      targetContract: targetContract ?? this.targetContract,
      functionSignature: functionSignature ?? this.functionSignature,
      description: description ?? this.description,
    );
  }
}

/// Provider for managing meta-transactions
class MetaTransactionProvider extends ChangeNotifier {
  final MetaTransactionRelayer _relayer;
  
  /// Maximum number of free transactions per day
  final int _maxDailyQuota = 10;
  
  /// Current quota usage
  int _usedQuota = 0;
  
  /// When the quota resets
  DateTime _quotaResetTime = DateTime.now().add(const Duration(days: 1));
  
  /// List of recent transactions
  final List<MetaTransaction> _transactions = [];
  
  /// Timer for checking transaction status
  Timer? _statusCheckTimer;
  
  /// Avalanche configuration
  final String _domainName;
  final String _domainVersion;
  final String _typeName;
  final String _typeSuffixData;
  final String _trustedForwarderAddress;
  
  /// Constructor
  MetaTransactionProvider({
    required MetaTransactionService metaTransactionService,
    required MetaTransactionRelayer relayer,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
  }) : _relayer = relayer,
       _domainName = domainName,
       _domainVersion = domainVersion,
       _typeName = typeName,
       _typeSuffixData = typeSuffixData,
       _trustedForwarderAddress = trustedForwarderAddress {
    _initQuota();
    _startStatusCheckTimer();
  }
  
  /// Initialize quota from storage
  Future<void> _initQuota() async {
    // In a real implementation, this would load from secure storage
    // For now, we'll use default values
    _usedQuota = 0;
    _quotaResetTime = DateTime.now().add(const Duration(days: 1));
    notifyListeners();
  }
  
  /// Start timer to periodically check transaction status
  void _startStatusCheckTimer() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkPendingTransactions(),
    );
  }
  
  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
  
  /// Get the list of recent transactions
  List<MetaTransaction> get transactions => List.unmodifiable(_transactions);
  
  /// Get the number of remaining free transactions
  int get remainingQuota => _maxDailyQuota - _usedQuota;
  
  /// Get the total daily quota
  int get totalQuota => _maxDailyQuota;
  
  /// Get the time when the quota will reset
  DateTime get quotaResetTime => _quotaResetTime;
  
  /// Check if user has quota available
  bool get hasQuotaAvailable => _usedQuota < _maxDailyQuota;
  
  /// Execute a function via meta-transaction
  Future<String> executeFunction({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String description,
  }) async {
    if (!hasQuotaAvailable) {
      throw Exception('Daily meta-transaction quota exceeded');
    }
    
    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Create a new transaction record
    final transaction = MetaTransaction(
      id: transactionId,
      status: MetaTransactionStatus.submitted,
      timestamp: DateTime.now(),
      targetContract: targetContract,
      functionSignature: functionSignature,
      description: description,
    );
    
    // Add to transactions list
    _transactions.insert(0, transaction);
    notifyListeners();
    
    try {
      // Execute the transaction with Avalanche-specific parameters
      final txHash = await _relayer.executeFunction(
        targetContract: targetContract,
        functionSignature: functionSignature,
        functionParams: functionParams,
        domainName: _domainName,
        domainVersion: _domainVersion,
        typeName: _typeName,
        typeSuffixData: _typeSuffixData,
        trustedForwarderAddress: _trustedForwarderAddress,
      );
      
      // Update transaction status
      _updateTransaction(
        transactionId,
        status: MetaTransactionStatus.processing,
        txHash: txHash,
      );
      
      // Increment used quota
      _usedQuota++;
      notifyListeners();
      
      return txHash;
    } catch (e) {
      // Update transaction status on error
      _updateTransaction(
        transactionId,
        status: MetaTransactionStatus.failed,
        error: e.toString(),
      );
      
      rethrow;
    }
  }
  
  /// Update a transaction's status
  void _updateTransaction(
    String id, {
    MetaTransactionStatus? status,
    String? txHash,
    String? error,
  }) {
    final index = _transactions.indexWhere((tx) => tx.id == id);
    if (index >= 0) {
      _transactions[index] = _transactions[index].copyWith(
        status: status,
        txHash: txHash,
        error: error,
      );
      notifyListeners();
    }
  }
  
  /// Check status of pending transactions
  Future<void> _checkPendingTransactions() async {
    final pendingTransactions = _transactions.where(
      (tx) => tx.status == MetaTransactionStatus.processing,
    ).toList();
    
    for (final tx in pendingTransactions) {
      try {
        // In a real implementation, this would check the blockchain
        // For now, we'll simulate it with a random success after a delay
        if (tx.timestamp.add(const Duration(seconds: 30)).isBefore(DateTime.now())) {
          _updateTransaction(
            tx.id,
            status: MetaTransactionStatus.confirmed,
          );
        }
      } catch (e) {
        debugPrint('Error checking transaction status: $e');
      }
    }
    
    // Check if quota should reset
    if (DateTime.now().isAfter(_quotaResetTime)) {
      _usedQuota = 0;
      _quotaResetTime = DateTime.now().add(const Duration(days: 1));
      notifyListeners();
    }
  }
  
  /// Clear transaction history
  void clearHistory() {
    _transactions.clear();
    notifyListeners();
  }
}
