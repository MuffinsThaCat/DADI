import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/screens/wallet_screen.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;

  setUp(() {
    walletService = MockWalletService();
  });

  group('WalletScreen Tests', () {
    testWidgets('Should show create/import tabs when wallet does not exist', (WidgetTester tester) async {
      // Setup wallet in non-created state
      walletService = MockWalletService();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: const WalletScreen(),
          ),
        ),
      );
      
      // Wait for async operations to complete
      await tester.pumpAndSettle();
      
      // Verify create/import tabs are shown
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      
      // Verify create widget is shown by default
      expect(find.text('Create New Wallet'), findsOneWidget);
      
      // Switch to import tab
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      
      // Verify import widget is shown
      expect(find.text('Import Existing Wallet'), findsOneWidget);
    });
    
    testWidgets('Should show wallet details when wallet exists', (WidgetTester tester) async {
      // Setup wallet in created state
      await walletService.createWallet(password: 'password123');
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: const WalletScreen(),
          ),
        ),
      );
      
      // Wait for async operations to complete
      await tester.pumpAndSettle();
      
      // Verify wallet details are shown
      expect(find.text('Wallet Address'), findsOneWidget);
      expect(find.text('Balance: 1.5 ETH'), findsOneWidget);
      
      // Verify action buttons are present
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('RECEIVE'), findsOneWidget);
    });
    
    testWidgets('Should show loading indicator while checking wallet status', (WidgetTester tester) async {
      // Setup wallet with delayed initialization
      walletService = MockWalletService(delayInitialization: true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MockWalletService>.value(
            value: walletService,
            child: const WalletScreen(),
          ),
        ),
      );
      
      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the initialization
      await tester.pumpAndSettle();
      
      // Verify create/import tabs are shown after loading
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
    });
  });
}
