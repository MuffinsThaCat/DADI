import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/providers/meta_transaction_provider.dart';
import 'package:dadi/widgets/transaction_status_widget.dart';

void main() {
  group('Transaction Status Widget Tests', () {
    testWidgets('Displays processing transaction correctly', (WidgetTester tester) async {
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
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionStatusWidget(
              transaction: transaction,
              compact: true,
            ),
          ),
        ),
      );
      
      // Verify processing state is displayed correctly
      expect(find.text('Processing'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });
    
    testWidgets('Displays confirmed transaction correctly', (WidgetTester tester) async {
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
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionStatusWidget(
              transaction: transaction,
              compact: true,
            ),
          ),
        ),
      );
      
      // Verify confirmed state is displayed correctly
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
    
    testWidgets('Displays failed transaction correctly', (WidgetTester tester) async {
      // Create a transaction in failed state
      final transaction = MetaTransaction(
        id: '1',
        txHash: '0x1234567890abcdef',
        status: MetaTransactionStatus.failed,
        error: 'Transaction reverted: insufficient funds',
        timestamp: DateTime.now(),
        targetContract: '0xcontract',
        functionSignature: 'test()',
        description: 'Test Transaction',
      );
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionStatusWidget(
              transaction: transaction,
              compact: true,
            ),
          ),
        ),
      );
      
      // Verify failed state is displayed correctly
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
    
    testWidgets('Displays detailed transaction view correctly', (WidgetTester tester) async {
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
            ),
          ),
        ),
      );
      
      // Verify detailed view shows transaction details
      expect(find.text('Test Transaction'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Transaction Hash'), findsOneWidget);
      expect(find.text('0x1234567890abcdef'), findsOneWidget);
      expect(find.text('Target Contract'), findsOneWidget);
      expect(find.text('0xcontract'), findsOneWidget);
    });
    
    testWidgets('Displays detailed error message for failed transaction', (WidgetTester tester) async {
      // Create a transaction in failed state
      final transaction = MetaTransaction(
        id: '1',
        txHash: '0x1234567890abcdef',
        status: MetaTransactionStatus.failed,
        error: 'Transaction reverted: insufficient funds',
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
            ),
          ),
        ),
      );
      
      // Verify detailed view shows error message
      expect(find.text('Test Transaction'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Error: Transaction reverted: insufficient funds'), findsOneWidget);
    });
  });
}
