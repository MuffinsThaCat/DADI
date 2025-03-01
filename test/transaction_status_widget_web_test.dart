import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/providers/meta_transaction_provider.dart';
import 'package:dadi/widgets/transaction_status_widget.dart';
import 'package:provider/provider.dart';
import 'package:dadi/contracts/meta_transaction_relayer.dart';
import 'package:mockito/mockito.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

import 'meta_transaction_service_mock.dart';

// Mock implementation for web testing
class WebMockMetaTransactionService extends MockMetaTransactionService {
  WebMockMetaTransactionService({
    required super.walletService,
    super.webSocketService,
  });
  
  bool get isWeb => true;
}

// Mock relayer for testing
class MockMetaTransactionRelayer extends Mock implements MetaTransactionRelayer {
  @override
  Future<String?> getUserAddress() async => '0xTestUser';
  
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
    return 'mock-transaction-id';
  }
}

// A simple test transaction provider that allows us to test the UI
class SimpleTestProvider extends ChangeNotifier implements MetaTransactionProvider {
  final List<MetaTransaction> _transactions = [];
  
  @override
  List<MetaTransaction> get transactions => List.unmodifiable(_transactions);
  
  // Add a test transaction for testing purposes
  void addTestTransaction(MetaTransaction transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }
  
  // Implement required methods from MetaTransactionProvider
  @override
  Future<String> executeFunction({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String description,
  }) async {
    throw UnimplementedError('Not needed for this test');
  }
  
  @override
  void clearHistory() {
    _transactions.clear();
    notifyListeners();
  }
  
  @override
  int get remainingQuota => 10;
  
  @override
  DateTime get quotaResetTime => DateTime.now().add(const Duration(days: 1));
  
  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('Transaction Status Widget Web Tests', () {
    testWidgets('Displays transaction with web-specific styling', (WidgetTester tester) async {
      // Create a transaction in processing state
      final transaction = MetaTransaction(
        id: '1',
        txHash: '0x1234567890abcdef',
        status: MetaTransactionStatus.processing,
        timestamp: DateTime.now(),
        targetContract: '0xcontract',
        functionSignature: 'test()',
        description: 'Test Transaction',
      );
      
      // Build the widget with web-specific theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            // Web-specific theme settings
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: TransactionStatusWidget(
              transaction: transaction,
              compact: true,
              // Web-specific parameters
              useWebStyling: true,
            ),
          ),
        ),
      );
      
      // Verify processing state is displayed correctly
      expect(find.text('Processing'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });
    
    testWidgets('Displays transaction with block explorer link on web', (WidgetTester tester) async {
      // Create a transaction in confirmed state
      final transaction = MetaTransaction(
        id: '1',
        txHash: '0x1234567890abcdef',
        status: MetaTransactionStatus.confirmed,
        timestamp: DateTime.now(),
        targetContract: '0xcontract',
        functionSignature: 'test()',
        description: 'Test Transaction',
      );
      
      // Build the widget in detailed mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionStatusWidget(
              transaction: transaction,
              compact: false,
              // Web-specific parameters
              useWebStyling: true,
              showBlockExplorerLink: true,
              blockExplorerUrl: 'https://snowtrace.io/tx/',
            ),
          ),
        ),
      );
      
      // Verify block explorer link is displayed
      expect(find.textContaining('View on'), findsOneWidget);
      // The text might be 'View on Snowtrace' or similar, so we use a partial match
    });
    
    testWidgets('Web provider integration test', (WidgetTester tester) async {
      // Create a simple test provider
      final provider = SimpleTestProvider();
      
      // Add a test transaction
      final testTransaction = MetaTransaction(
        id: '1',
        txHash: '0x1234567890abcdef',
        status: MetaTransactionStatus.confirmed,
        timestamp: DateTime.now(),
        targetContract: '0xcontract',
        functionSignature: 'test()',
        description: 'Test Transaction',
      );
      
      // Add transaction to provider
      provider.addTestTransaction(testTransaction);
      
      // Build widget tree with provider
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SimpleTestProvider>.value(
            value: provider,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final provider = Provider.of<SimpleTestProvider>(context);
                  return TransactionStatusWidget(
                    transaction: provider.transactions.first,
                    compact: true,
                    useWebStyling: true,
                  );
                },
              ),
            ),
          ),
        ),
      );
      
      // Verify transaction is displayed
      expect(find.text('Test Transaction'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });
  });
}
