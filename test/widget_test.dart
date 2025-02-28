import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/screens/home_screen.dart';
import 'dart:developer' as developer;

// Improved mock implementation of Web3Service
class MockWeb3Service extends ChangeNotifier {
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }
  
  void connect() {
    developer.log('Connecting Web3Service');
    _isConnected = true;
    notifyListeners();
  }
  
  void disconnect() {
    developer.log('Disconnecting Web3Service');
    _isConnected = false;
    notifyListeners();
  }
}

// Improved mock implementation of ButtplugService
class MockButtplugService extends ChangeNotifier {
  bool _isConnected = false;
  List<String> _availableDevices = ['Test Device 1', 'Test Device 2'];
  
  bool get isConnected => _isConnected;
  List<String> get availableDevices => _availableDevices;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }
  
  void connect() {
    developer.log('Connecting ButtplugService');
    _isConnected = true;
    notifyListeners();
  }
  
  void disconnect() {
    developer.log('Disconnecting ButtplugService');
    _isConnected = false;
    notifyListeners();
  }
  
  void setAvailableDevices(List<String> devices) {
    _availableDevices = devices;
    notifyListeners();
  }
}

void main() {
  late MockWeb3Service mockWeb3Service;
  late MockButtplugService mockButtplugService;

  setUp(() {
    mockWeb3Service = MockWeb3Service();
    mockButtplugService = MockButtplugService();
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MockWeb3Service>.value(value: mockWeb3Service),
        ChangeNotifierProvider<MockButtplugService>.value(value: mockButtplugService),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Tests', () {
    testWidgets('Shows connect wallet button when not connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Connect Wallet'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    });

    testWidgets('Shows connect device button when wallet connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Connect Device'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    });

    testWidgets('Shows wallet connected icon when wallet is connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('Shows device connected icon when device is connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(true);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
    });

    testWidgets('Can connect wallet by tapping connect button',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect Wallet'));
      await tester.pumpAndSettle();

      // State should be updated after tapping
      expect(mockWeb3Service.isConnected, isTrue);
    });

    testWidgets('Can connect device by tapping connect button',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect Device'));
      await tester.pumpAndSettle();

      // State should be updated after tapping
      expect(mockButtplugService.isConnected, isTrue);
    });
  });
}
