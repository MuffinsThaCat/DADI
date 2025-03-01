import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/providers/meta_transaction_provider.dart';
import 'package:dadi/services/transaction_websocket_service.dart';
import 'package:dadi/contracts/meta_transaction_relayer.dart';
import 'package:dadi/services/wallet_service_interface.dart';

import 'meta_transaction_service_mock.dart';
import 'wallet_service_mock.dart';

// Mock WebSocket service with controllable behavior
class MockTransactionWebSocketService extends TransactionWebSocketService {
  final Map<String, Function(TransactionStatusUpdate)> _transactionCallbacks = {};
  final Map<String, Function(TransactionStatusUpdate)> _userCallbacks = {};
  bool _initialized = false;
  
  MockTransactionWebSocketService() : super(
    webSocketUrl: 'wss://test.example.com/ws',
  );
  
  @override
  Future<void> initialize() async {
    _initialized = true;
    return Future.value();
  }
  
  bool get isInitialized => _initialized;
  
  @override
  void watchTransaction(String txHash, Function(TransactionStatusUpdate) callback) {
    _transactionCallbacks[txHash] = callback;
  }
  
  @override
  void unwatchTransaction(String txHash) {
    _transactionCallbacks.remove(txHash);
  }
  
  @override
  void watchUserTransactions(String userAddress, Function(TransactionStatusUpdate) callback) {
    _userCallbacks[userAddress] = callback;
  }
  
  @override
  void unwatchUserTransactions(String userAddress) {
    _userCallbacks.remove(userAddress);
  }
  
  // Helper method to simulate transaction updates
  @override
  void simulateTransactionUpdate({
    required String txHash,
    required TransactionStatus status,
    int? blockNumber,
    int? confirmations,
    int? gasUsed,
    String? errorMessage,
  }) {
    final update = TransactionStatusUpdate(
      txHash: txHash,
      status: status,
      blockNumber: blockNumber,
      confirmations: confirmations,
      gasUsed: gasUsed,
      errorMessage: errorMessage,
    );
    
    // Call both transaction-specific and user-level callbacks
    final callback = _transactionCallbacks[txHash];
    if (callback != null) {
      callback(update);
    }
    
    // Call user-level callbacks for all registered users
    for (final userCallback in _userCallbacks.values) {
      userCallback(update);
    }
  }
  
  // Helper method to simulate user transaction updates
  void simulateUserTransactionUpdate(String userAddress, String txHash, TransactionStatus status) {
    final callback = _userCallbacks[userAddress];
    if (callback != null) {
      callback(TransactionStatusUpdate(
        txHash: txHash,
        status: status,
      ));
    }
  }
}

// Mock MetaTransaction Relayer with controllable behavior
class MockMetaTransactionRelayer implements MetaTransactionRelayer {
  final String _userAddress;
  final Map<String, TransactionStatus> _transactionStatuses = {};
  int _txCounter = 0;
  
  MockMetaTransactionRelayer({String userAddress = '0xuser1234567890'})
      : _userAddress = userAddress;
  
  @override
  Future<String> executeFunction({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
    int? gasLimit,
    int? validUntilTime,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    _txCounter++;
    final txHash = 'mock_tx_hash_${_txCounter}_${DateTime.now().millisecondsSinceEpoch}';
    _transactionStatuses[txHash] = TransactionStatus.submitted;
    
    // Simulate initial status update
    if (onStatusUpdate != null) {
      onStatusUpdate(TransactionStatusUpdate(
        txHash: txHash,
        status: TransactionStatus.submitted,
      ));
    }
    
    return txHash;
  }
  
  @override
  Future<String?> getUserAddress() async {
    return _userAddress;
  }
  
  Future<int> getQuota() async {
    return 10;
  }
  
  Future<int> getUsedQuota() async {
    return 2;
  }
  
  Future<DateTime> getQuotaResetTime() async {
    return DateTime.now().add(const Duration(hours: 12));
  }
  
  @override
  Stream<TransactionStatusUpdate>? getTransactionStatusStream(String txHash) {
    return null;
  }
  
  @override
  Stream<TransactionStatusUpdate>? getUserTransactionStatusStream(String userAddress) {
    return null;
  }
  
  @override
  void unwatchTransaction(String txHash) {
    // No implementation needed for mock
  }
  
  @override
  void unwatchUserTransactions(String userAddress) {
    // No implementation needed for mock
  }
  
  @override
  Future<bool> checkQuotaAvailable({required WalletServiceInterface walletService}) async {
    return true;
  }
  
  @override
  Future<BigInt> estimateGasCost({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
  }) async {
    return BigInt.from(500000);
  }
}

void main() {
  group('Transaction Service Integration Tests', () {
    late MockWalletService mockWalletService;
    late MockTransactionWebSocketService mockWebSocketService;
    late MockMetaTransactionService mockMetaTransactionService;
    late MockMetaTransactionRelayer mockRelayer;
    late MetaTransactionProvider provider;
    
    setUp(() async {
      mockWalletService = MockWalletService();
      mockWebSocketService = MockTransactionWebSocketService();
      mockRelayer = MockMetaTransactionRelayer();
      mockMetaTransactionService = MockMetaTransactionService(
        walletService: mockWalletService,
        webSocketService: mockWebSocketService,
      );
      
      provider = MetaTransactionProvider(
        metaTransactionService: mockMetaTransactionService,
        relayer: mockRelayer,
        webSocketService: mockWebSocketService,
        domainName: 'Test',
        domainVersion: '1',
        typeName: 'MetaTransaction',
        typeSuffixData: '',
        trustedForwarderAddress: '0xforwarder',
      );
      
      // Initialize WebSocket service
      await mockWebSocketService.initialize();
      
      // Setup wallet
      await mockWalletService.createWallet(password: 'password123');
      mockWalletService.unlock();
      mockWalletService.setAddress('0xuser1234567890');
    });
    
    test('Transaction submission adds transaction to provider', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract',
        functionSignature: 'test()',
        functionParams: [],
        description: 'Test Transaction',
      );
      
      // Verify transaction is added to provider
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.txHash, txHash);
      expect(provider.transactions.first.status, MetaTransactionStatus.processing);
    });
    
    test('WebSocket updates change transaction status', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract',
        functionSignature: 'test()',
        functionParams: [],
        description: 'Test Transaction',
      );
      
      // Verify initial status
      expect(provider.transactions.first.status, MetaTransactionStatus.processing);
      
      // Update transaction status via WebSocket
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash,
        status: TransactionStatus.confirmed,
        blockNumber: 12345,
        confirmations: 3,
        gasUsed: 50000,
      );
      
      // Verify status is updated
      expect(provider.transactions.first.status, MetaTransactionStatus.confirmed);
    });
    
    test('Failed transaction includes error message', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract',
        functionSignature: 'test()',
        functionParams: [],
        description: 'Test Transaction',
      );
      
      // Update transaction status to failed with error message
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash,
        status: TransactionStatus.failed,
        errorMessage: 'Transaction reverted: insufficient funds',
      );
      
      // Verify status and error message
      expect(provider.transactions.first.status, MetaTransactionStatus.failed);
      expect(provider.transactions.first.error, 'Transaction reverted: insufficient funds');
    });
    
    test('First transaction can be confirmed', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract1',
        functionSignature: 'test1()',
        functionParams: [],
        description: 'Transaction 1',
      );
      
      // Verify initial status
      expect(provider.transactions.first.status, MetaTransactionStatus.processing);
      
      // Update transaction status via WebSocket
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash,
        status: TransactionStatus.confirmed,
      );
      
      // Verify status is updated
      expect(provider.transactions.first.status, MetaTransactionStatus.confirmed);
    });
    
    test('Second transaction can be failed', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract2',
        functionSignature: 'test2()',
        functionParams: [],
        description: 'Transaction 2',
      );
      
      // Verify initial status
      expect(provider.transactions.first.status, MetaTransactionStatus.processing);
      
      // Update transaction status via WebSocket
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash,
        status: TransactionStatus.failed,
        errorMessage: 'Out of gas',
      );
      
      // Verify status and error message
      expect(provider.transactions.first.status, MetaTransactionStatus.failed);
      expect(provider.transactions.first.error, 'Out of gas');
    });
    
    test('Multiple transactions can be tracked', () async {
      // Execute first transaction
      await provider.executeFunction(
        targetContract: '0xcontract1',
        functionSignature: 'test1()',
        functionParams: [],
        description: 'Transaction 1',
      );
      
      // Execute second transaction
      await provider.executeFunction(
        targetContract: '0xcontract2',
        functionSignature: 'test2()',
        functionParams: [],
        description: 'Transaction 2',
      );
      
      // Verify both transactions are added
      expect(provider.transactions.length, 2);
      
      // Verify we can find both transactions by description
      final tx1 = provider.transactions.firstWhere((tx) => tx.description == 'Transaction 1');
      final tx2 = provider.transactions.firstWhere((tx) => tx.description == 'Transaction 2');
      
      expect(tx1.description, 'Transaction 1');
      expect(tx2.description, 'Transaction 2');
    });
    
    test('WebSocket reconnection preserves transaction tracking', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract',
        functionSignature: 'test()',
        functionParams: [],
        description: 'Test Transaction',
      );
      
      // Simulate WebSocket disconnection and reconnection
      mockWebSocketService._initialized = false;
      await mockWebSocketService.initialize();
      
      // Update transaction status after reconnection
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash,
        status: TransactionStatus.confirmed,
      );
      
      // Verify status is still updated correctly
      expect(provider.transactions.first.status, MetaTransactionStatus.confirmed);
    });
    
    test('User-level transaction updates are processed', () async {
      // Execute a transaction
      final txHash = await provider.executeFunction(
        targetContract: '0xcontract',
        functionSignature: 'test()',
        functionParams: [],
        description: 'Test Transaction',
      );
      
      // Simulate user-level transaction update
      mockWebSocketService.simulateUserTransactionUpdate(
        '0xuser1234567890',
        txHash,
        TransactionStatus.confirmed,
      );
      
      // Verify status is updated
      expect(provider.transactions.first.status, MetaTransactionStatus.confirmed);
    });
    
    test('Transaction history is preserved', () async {
      // Execute and complete multiple transactions
      final txHash1 = await provider.executeFunction(
        targetContract: '0xcontract1',
        functionSignature: 'test1()',
        functionParams: [],
        description: 'Transaction 1',
      );
      
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash1,
        status: TransactionStatus.confirmed,
      );
      
      final txHash2 = await provider.executeFunction(
        targetContract: '0xcontract2',
        functionSignature: 'test2()',
        functionParams: [],
        description: 'Transaction 2',
      );
      
      mockWebSocketService.simulateTransactionUpdate(
        txHash: txHash2,
        status: TransactionStatus.failed,
        errorMessage: 'Out of gas',
      );
      
      // Verify transaction history is preserved
      expect(provider.transactions.length, 2);
      expect(provider.transactions.where((tx) => tx.status == MetaTransactionStatus.confirmed).length, 1);
      expect(provider.transactions.where((tx) => tx.status == MetaTransactionStatus.failed).length, 1);
    });
  });
}
