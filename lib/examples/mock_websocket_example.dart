import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/transaction_websocket_service.dart';
import '../services/transaction_websocket_service_platform.dart';
import '../services/mock_transaction_helper.dart';

/// Example widget demonstrating how to use the mock WebSocket service
class MockWebSocketExample extends StatefulWidget {
  const MockWebSocketExample({Key? key}) : super(key: key);

  @override
  _MockWebSocketExampleState createState() => _MockWebSocketExampleState();
}

class _MockWebSocketExampleState extends State<MockWebSocketExample> {
  /// WebSocket service
  late final TransactionWebSocketService _webSocketService;
  
  /// Mock transaction helper
  late final MockTransactionHelper _mockHelper;
  
  /// List of transaction status updates
  final List<TransactionStatusUpdate> _updates = [];
  
  /// Current transaction hash
  String? _currentTxHash;
  
  @override
  void initState() {
    super.initState();
    
    // Create WebSocket service with mock mode enabled
    _webSocketService = createTransactionWebSocketService(
      webSocketUrl: 'wss://relayer.dadi.network/ws',
      useMockMode: true, // Always use mock mode for this example
    );
    
    // Initialize WebSocket service
    _webSocketService.initialize().then((_) {
      // Create mock transaction helper
      _mockHelper = MockTransactionHelper(
        webSocketService: _webSocketService,
      );
      
      // Watch for transaction updates
      _webSocketService.watchUserTransactions(
        'mock_user_address',
        _handleTransactionUpdate,
      );
    });
  }
  
  @override
  void dispose() {
    // Clean up resources
    _mockHelper.dispose();
    _webSocketService.dispose();
    super.dispose();
  }
  
  /// Handle transaction status updates
  void _handleTransactionUpdate(TransactionStatusUpdate update) {
    setState(() {
      _updates.add(update);
    });
  }
  
  /// Simulate a successful transaction
  void _simulateSuccessfulTransaction() {
    setState(() {
      _currentTxHash = _mockHelper.simulateNewTransaction(
        shouldSucceed: true,
        submittedDuration: 2000,
        processingDuration: 3000,
      );
    });
  }
  
  /// Simulate a failed transaction
  void _simulateFailedTransaction() {
    setState(() {
      _currentTxHash = _mockHelper.simulateNewTransaction(
        shouldSucceed: false,
        submittedDuration: 1000,
        processingDuration: 2000,
      );
    });
  }
  
  /// Get status text for a transaction status
  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.submitted:
        return 'Submitted';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.dropped:
        return 'Dropped';
      case TransactionStatus.unknown:
        return 'Unknown';
    }
  }
  
  /// Get color for a transaction status
  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.submitted:
        return Colors.blue;
      case TransactionStatus.processing:
        return Colors.orange;
      case TransactionStatus.confirmed:
        return Colors.green;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.dropped:
        return Colors.red;
      case TransactionStatus.unknown:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock WebSocket Example'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _simulateSuccessfulTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Simulate Success'),
                ),
                ElevatedButton(
                  onPressed: _simulateFailedTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Simulate Failure'),
                ),
              ],
            ),
          ),
          if (_currentTxHash != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Transaction:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Hash: $_currentTxHash'),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _updates.isEmpty
                ? const Center(
                    child: Text('No transaction updates yet'),
                  )
                : ListView.builder(
                    itemCount: _updates.length,
                    itemBuilder: (context, index) {
                      final update = _updates[_updates.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: ListTile(
                          title: Text(
                            'TX: ${update.txHash.substring(0, 10)}...',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${_getStatusText(update.status)}',
                                style: TextStyle(
                                  color: _getStatusColor(update.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (update.blockNumber != null)
                                Text('Block: ${update.blockNumber}'),
                              if (update.errorMessage != null)
                                Text(
                                  'Error: ${update.errorMessage}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              Text(
                                'Time: ${update.timestamp.hour}:${update.timestamp.minute}:${update.timestamp.second}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
