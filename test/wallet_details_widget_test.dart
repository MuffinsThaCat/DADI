@TestOn('vm')
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/widgets/wallet_details_widget.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService mockWalletService;

  setUp(() {
    mockWalletService = MockWalletService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider<WalletServiceInterface>.value(
        value: mockWalletService,
        child: const Scaffold(
          body: WalletDetailsWidget(),
        ),
      ),
    );
  }

  group('WalletDetailsWidget Tests', () {
    testWidgets('Should display wallet not created message initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Wallet not created'), findsOneWidget);
      expect(find.text('Create New Wallet'), findsOneWidget);
      expect(find.text('Import Wallet'), findsOneWidget);
    });

    testWidgets('Should allow wallet creation', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Find and tap the create wallet button
      await tester.tap(find.text('Create New Wallet'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show password dialog
      expect(find.text('Create Wallet'), findsOneWidget);
      expect(find.text('Enter a password to secure your wallet'), findsOneWidget);

      // Enter password
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.pump(const Duration(milliseconds: 500));

      // Tap create button
      await tester.tap(find.text('Create').last);
      await tester.pump(const Duration(milliseconds: 500));

      // Should show wallet address
      expect(find.text('0x1234567890abcdef1234567890abcdef12345678'), findsOneWidget);
      expect(find.text('Balance: 1.5 ETH'), findsOneWidget);
    });

    testWidgets('Should allow wallet locking and unlocking', (WidgetTester tester) async {
      // Create wallet first
      await mockWalletService.createWallet(password: 'password123');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Should show wallet address and lock button
      expect(find.text('0x1234567890abcdef1234567890abcdef12345678'), findsOneWidget);
      expect(find.text('Lock Wallet'), findsOneWidget);

      // Tap lock button
      await tester.tap(find.text('Lock Wallet'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show wallet locked message
      expect(find.text('Wallet is locked'), findsOneWidget);
      expect(find.text('Unlock Wallet'), findsOneWidget);

      // Tap unlock button
      await tester.tap(find.text('Unlock Wallet'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show password dialog
      expect(find.text('Unlock Wallet'), findsOneWidget);
      expect(find.text('Enter your wallet password'), findsOneWidget);

      // Enter password
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.pump(const Duration(milliseconds: 500));

      // Tap unlock button
      await tester.tap(find.text('Unlock').last);
      await tester.pump(const Duration(milliseconds: 500));

      // Should show wallet address again
      expect(find.text('0x1234567890abcdef1234567890abcdef12345678'), findsOneWidget);
    });

    testWidgets('Should display transaction history', (WidgetTester tester) async {
      // Create wallet first
      await mockWalletService.createWallet(password: 'password123');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Should show transaction history section
      expect(find.text('Transaction History'), findsOneWidget);

      // Should have at least one transaction
      expect(find.byType(ListTile), findsAtLeast(1));
    });

    testWidgets('Should allow wallet reset', (WidgetTester tester) async {
      // Create wallet first
      await mockWalletService.createWallet(password: 'password123');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap reset wallet option
      await tester.tap(find.text('Reset Wallet'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show confirmation dialog
      expect(find.text('Reset Wallet?'), findsOneWidget);
      expect(find.text('This will delete your wallet. Make sure you have backed up your private key or mnemonic phrase.'), findsOneWidget);

      // Confirm reset
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show wallet not created message again
      expect(find.text('Wallet not created'), findsOneWidget);
    });

    testWidgets('Should show export options in menu', (WidgetTester tester) async {
      // Create wallet first
      await mockWalletService.createWallet(password: 'password123');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show export options
      expect(find.text('Export Private Key'), findsOneWidget);
      expect(find.text('Export Mnemonic'), findsOneWidget);
    });

    testWidgets('Should allow sending transactions', 
      skip: true, 
      (WidgetTester tester) async {
      // Create wallet first
      await mockWalletService.createWallet(password: 'password123');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap send button
      await tester.tap(find.text('Send'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show send dialog
      expect(find.text('Send ETH'), findsOneWidget);

      // Enter recipient address
      await tester.enterText(find.byKey(const ValueKey('address_field')), '0x0987654321098765432109876543210987654321');
      await tester.pump(const Duration(milliseconds: 500));

      // Enter amount
      await tester.enterText(find.byKey(const ValueKey('amount_field')), '0.1');
      await tester.pump(const Duration(milliseconds: 500));

      // Tap send button
      await tester.tap(find.text('Send').last);
      await tester.pump(const Duration(milliseconds: 500));

      // Should show transaction success message
      expect(find.text('Transaction sent!'), findsOneWidget);
    });
  });
}
