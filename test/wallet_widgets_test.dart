import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/widgets/wallet_create_widget.dart';
import 'package:dadi/widgets/wallet_import_widget.dart';
import 'package:dadi/widgets/wallet_details_widget.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;

  setUp(() {
    walletService = MockWalletService();
  });

  group('WalletCreateWidget Tests', () {
    testWidgets('Should show password fields and create button', (WidgetTester tester) async {
      bool walletCreatedCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: WalletCreateWidget(
              onWalletCreated: () {
                walletCreatedCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify UI elements are present
      expect(find.text('Create New Wallet'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('CREATE WALLET'), findsOneWidget);
      
      // Fill in password fields
      await tester.enterText(find.byType(TextField).at(0), 'password123');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      
      // Tap create button
      await tester.tap(find.text('CREATE WALLET'));
      await tester.pumpAndSettle();
      
      // Verify callback was called
      expect(walletCreatedCalled, true);
      
      // Verify wallet service was called
      expect(walletService.isCreated, true);
      expect(walletService.isUnlocked, true);
    });
    
    testWidgets('Should show error when passwords do not match', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: WalletCreateWidget(
              onWalletCreated: () {},
            ),
          ),
        ),
      );
      
      // Fill in mismatched passwords
      await tester.enterText(find.byType(TextField).at(0), 'password123');
      await tester.enterText(find.byType(TextField).at(1), 'password456');
      
      // Tap create button
      await tester.tap(find.text('CREATE WALLET'));
      await tester.pumpAndSettle();
      
      // Verify error message is shown
      expect(find.text('Passwords do not match'), findsOneWidget);
      
      // Verify wallet service was not called
      expect(walletService.isCreated, false);
    });
  });

  group('WalletImportWidget Tests', () {
    testWidgets('Should show import options and import button', (WidgetTester tester) async {
      bool walletImportedCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: WalletImportWidget(
              onWalletImported: () {
                walletImportedCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify UI elements are present
      expect(find.text('Import Existing Wallet'), findsOneWidget);
      expect(find.text('Mnemonic Phrase'), findsOneWidget);
      expect(find.text('Private Key'), findsOneWidget);
      
      // Select mnemonic option and fill in fields
      await tester.tap(find.text('Mnemonic Phrase'));
      await tester.pumpAndSettle();
      
      await tester.enterText(
        find.byType(TextField).first, 
        'test word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12'
      );
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      
      // Tap import button
      await tester.tap(find.text('IMPORT WALLET'));
      await tester.pumpAndSettle();
      
      // Verify callback was called
      expect(walletImportedCalled, true);
      
      // Verify wallet service was called
      expect(walletService.isCreated, true);
      expect(walletService.isUnlocked, true);
    });
  });

  group('WalletDetailsWidget Tests', () {
    testWidgets('Should show wallet address and balance when wallet is created', (WidgetTester tester) async {
      // Setup wallet in created state
      await walletService.createWallet(password: 'password123');
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: const WalletDetailsWidget(),
          ),
        ),
      );

      // Verify UI elements are present
      expect(find.text('Wallet Address'), findsOneWidget);
      expect(find.text('Balance: 1.5 ETH'), findsOneWidget);
      expect(find.text('0x1234...5678'), findsOneWidget);
      
      // Verify action buttons are present
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('RECEIVE'), findsOneWidget);
      expect(find.text('EXPORT'), findsOneWidget);
    });
    
    testWidgets('Should show loading indicator when fetching transactions', (WidgetTester tester) async {
      // Setup wallet in created state
      await walletService.createWallet(password: 'password123');
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: const WalletDetailsWidget(),
          ),
        ),
      );
      
      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the future
      await tester.pumpAndSettle();
      
      // Verify transactions are shown
      expect(find.text('Recent Transactions'), findsOneWidget);
    });
  });
}
