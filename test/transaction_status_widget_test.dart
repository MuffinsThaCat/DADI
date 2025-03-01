import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/widgets/transaction_status_widget.dart';
import 'package:dadi/providers/meta_transaction_provider.dart';

void main() {
  group('TransactionStatusWidget Tests', () {
    testWidgets('Should display compact status for submitted transaction',
        (WidgetTester tester) async {
      // Create a test transaction
      final transaction = MetaTransaction(
        id: 'test_id',
        txHash: '0x1234567890abcdef1234567890abcdef12345678',
        description: 'Test Transaction',
        timestamp: DateTime.now(),
        status: MetaTransactionStatus.submitted,
        targetContract: '0xTestContract',
        functionSignature: 'test()',
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

      // Verify the widget displays correctly
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('Should display compact status for processing transaction',
        (WidgetTester tester) async {
      // Create a test transaction
      final transaction = MetaTransaction(
        id: 'test_id',
        txHash: '0x1234567890abcdef1234567890abcdef12345678',
        description: 'Test Transaction',
        timestamp: DateTime.now(),
        status: MetaTransactionStatus.processing,
        targetContract: '0xTestContract',
        functionSignature: 'test()',
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

      // Verify the widget displays correctly
      expect(find.text('Processing'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('Should display compact status for confirmed transaction',
        (WidgetTester tester) async {
      // Create a test transaction
      final transaction = MetaTransaction(
        id: 'test_id',
        txHash: '0x1234567890abcdef1234567890abcdef12345678',
        description: 'Test Transaction',
        timestamp: DateTime.now(),
        status: MetaTransactionStatus.confirmed,
        targetContract: '0xTestContract',
        functionSignature: 'test()',
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

      // Verify the widget displays correctly
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Should display compact status for failed transaction',
        (WidgetTester tester) async {
      // Create a test transaction
      final transaction = MetaTransaction(
        id: 'test_id',
        txHash: '0x1234567890abcdef1234567890abcdef12345678',
        description: 'Test Transaction',
        timestamp: DateTime.now(),
        status: MetaTransactionStatus.failed,
        error: 'Test error message',
        targetContract: '0xTestContract',
        functionSignature: 'test()',
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

      // Verify the widget displays correctly
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('Should display detailed status when compact is false',
        (WidgetTester tester) async {
      // Create a test transaction
      final transaction = MetaTransaction(
        id: 'test_id',
        txHash: '0x1234567890abcdef1234567890abcdef12345678',
        description: 'Test Transaction',
        timestamp: DateTime.now(),
        status: MetaTransactionStatus.confirmed,
        targetContract: '0xTestContract',
        functionSignature: 'test()',
      );

      // Build the widget
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

      // Verify the widget displays correctly
      expect(find.text('Test Transaction'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Transaction Hash'), findsOneWidget);
      expect(find.text('0x1234567890abcdef1234567890abcdef12345678'), findsOneWidget);
      expect(find.text('Target Contract'), findsOneWidget);
      expect(find.text('0xTestContract'), findsOneWidget);
    });
  });
}
