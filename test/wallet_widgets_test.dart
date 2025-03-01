import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/widgets/wallet_create_widget.dart';
import 'package:dadi/widgets/wallet_import_widget.dart';
import 'package:dadi/widgets/wallet_details_widget.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;

  setUp(() {
    walletService = MockWalletService();
  });

  group('WalletCreateWidget Tests', () {
    testWidgets('Should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WalletServiceInterface>.value(
              value: walletService,
              child: WalletCreateWidget(
                onWalletCreated: () {},
              ),
            ),
          ),
        ),
      );

      // Verify basic UI elements are present
      expect(find.text('Create a New Wallet'), findsOneWidget);
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2)); // Password fields
      expect(find.byType(ElevatedButton), findsOneWidget); // Create button
    });
  });

  group('WalletImportWidget Tests', () {
    testWidgets('Should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WalletServiceInterface>.value(
              value: walletService,
              child: WalletImportWidget(
                onWalletImported: () {},
              ),
            ),
          ),
        ),
      );

      // Verify basic UI elements are present
      expect(find.text('Import Existing Wallet'), findsOneWidget);
      expect(find.byType(TextFormField), findsAtLeastNWidgets(1)); // Import data field
      expect(find.byType(ElevatedButton), findsOneWidget); // Import button
    });
  });

  group('WalletDetailsWidget Tests', () {
    testWidgets('Should render unlock screen when wallet is locked', (WidgetTester tester) async {
      // Setup wallet in created state but locked
      await walletService.createWallet(password: 'password123');
      // Explicitly lock the wallet after creation
      await walletService.lockWallet();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WalletServiceInterface>.value(
              value: walletService,
              child: const WalletDetailsWidget(),
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();
      
      // Verify unlock screen is shown - look for text that should be present in the unlock screen
      expect(find.text('Wallet is Locked'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Password field
      expect(find.text('UNLOCK WALLET'), findsOneWidget); // Unlock button
    });
  });
}
