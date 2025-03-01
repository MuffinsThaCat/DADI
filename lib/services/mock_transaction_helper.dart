import 'dart:async';
import 'package:flutter/foundation.dart';
import 'transaction_websocket_service.dart';

/// Helper class for simulating transaction status updates in mock mode
/// This is useful for testing and development without a real WebSocket connection
class MockTransactionHelper {
  /// WebSocket service to send mock updates to
  final TransactionWebSocketService _webSocketService;
  
  /// Map of transaction hash to timer for auto-progression
  final Map<String, Timer> _progressionTimers = {};
  
  /// Constructor
  MockTransactionHelper({
    required TransactionWebSocketService webSocketService,
  }) : _webSocketService = webSocketService {
    if (!webSocketService.useMockMode) {
      debugPrint('Warning: MockTransactionHelper created with non-mock WebSocket service');
    }
  }
  
  /// Simulate a new transaction with automatic status progression
  /// This will automatically progress the transaction through the typical lifecycle:
  /// submitted -> processing -> confirmed (or failed)
  /// 
  /// Returns the transaction hash
  String simulateNewTransaction({
    String? txHash,
    bool shouldSucceed = true,
    int submittedDuration = 2000,  // 2 seconds in submitted state
    int processingDuration = 5000, // 5 seconds in processing state
  }) {
    // Generate a random transaction hash if not provided
    final hash = txHash ?? 'mock_tx_${DateTime.now().millisecondsSinceEpoch}';
    
    // Initial status: submitted
    _webSocketService.simulateTransactionUpdate(
      txHash: hash,
      status: TransactionStatus.submitted,
    );
    
    // Schedule transition to processing
    _progressionTimers[hash] = Timer(Duration(milliseconds: submittedDuration), () {
      _webSocketService.simulateTransactionUpdate(
        txHash: hash,
        status: TransactionStatus.processing,
      );
      
      // Schedule transition to final state (confirmed or failed)
      _progressionTimers[hash] = Timer(Duration(milliseconds: processingDuration), () {
        if (shouldSucceed) {
          _webSocketService.simulateTransactionUpdate(
            txHash: hash,
            status: TransactionStatus.confirmed,
            blockNumber: 12345678,
            confirmations: 1,
            gasUsed: 100000,
          );
        } else {
          _webSocketService.simulateTransactionUpdate(
            txHash: hash,
            status: TransactionStatus.failed,
            errorMessage: 'Mock transaction failure',
          );
        }
        
        _progressionTimers.remove(hash);
      });
    });
    
    return hash;
  }
  
  /// Simulate a transaction failure immediately
  void simulateTransactionFailure({
    required String txHash,
    String errorMessage = 'Mock transaction failure',
  }) {
    // Cancel any existing progression timer
    _progressionTimers[txHash]?.cancel();
    _progressionTimers.remove(txHash);
    
    // Update status to failed
    _webSocketService.simulateTransactionUpdate(
      txHash: txHash,
      status: TransactionStatus.failed,
      errorMessage: errorMessage,
    );
  }
  
  /// Simulate a transaction confirmation immediately
  void simulateTransactionConfirmation({
    required String txHash,
    int blockNumber = 12345678,
    int confirmations = 1,
  }) {
    // Cancel any existing progression timer
    _progressionTimers[txHash]?.cancel();
    _progressionTimers.remove(txHash);
    
    // Update status to confirmed
    _webSocketService.simulateTransactionUpdate(
      txHash: txHash,
      status: TransactionStatus.confirmed,
      blockNumber: blockNumber,
      confirmations: confirmations,
      gasUsed: 100000,
    );
  }
  
  /// Dispose of all timers
  void dispose() {
    for (final timer in _progressionTimers.values) {
      timer.cancel();
    }
    _progressionTimers.clear();
  }
}
