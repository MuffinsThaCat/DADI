import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/screens/home_screen.dart';
import 'package:dadi/services/web3_service.dart';
import 'package:dadi/services/mock_buttplug_service.dart';
import 'dart:developer' as developer;

// Mock implementation of Web3Service for testing
class MockWeb3Service extends ChangeNotifier implements Web3Service {
  bool _isConnected = false;
  bool _isContractInitialized = false;
  bool _isMockMode = true;
  Map<String, Map<String, dynamic>> _auctions = {};
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  bool get isContractInitialized => _isContractInitialized;
  
  @override
  bool get isMockMode => _isMockMode;
  
  @override
  Map<String, Map<String, dynamic>> get activeAuctions => _auctions;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }
  
  @override
  Future<bool> connect() async {
    developer.log('Connecting Web3Service');
    _isConnected = true;
    notifyListeners();
    return true;
  }
  
  @override
  Future<void> disconnect() async {
    developer.log('Disconnecting Web3Service');
    _isConnected = false;
    notifyListeners();
  }
  
  @override
  Future<bool> initializeContract() async {
    _isContractInitialized = true;
    notifyListeners();
    return true;
  }
  
  @override
  Future<bool> testContract() async {
    return true;
  }
  
  @override
  Future<void> loadActiveAuctions() async {
    _auctions = {
      '0x1234': {'id': '0x1234', 'title': 'Test Auction 1', 'description': 'Test Description 1'},
      '0x5678': {'id': '0x5678', 'title': 'Test Auction 2', 'description': 'Test Description 2'},
    };
    notifyListeners();
  }
  
  @override
  Future<bool> toggleMockMode() async {
    _isMockMode = !_isMockMode;
    notifyListeners();
    return true;
  }
  
  // Implement other required methods with stub implementations
  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Test-specific implementation of MockButtplugService
class TestButtplugService extends ChangeNotifier implements MockButtplugService {
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String? get currentDevice => _currentDevice;
  
  @override
  double get currentVibration => _currentVibration;
  
  @override
  Future<void> connect() async {
    // No delay in tests
    _isConnected = true;
    _currentDevice = 'Mock Device 1';
    notifyListeners();
  }
  
  @override
  Future<void> disconnect() async {
    // No delay in tests
    _isConnected = false;
    _currentDevice = null;
    _currentVibration = 0.0;
    notifyListeners();
  }
  
  @override
  Future<void> startVibration(double intensity) async {
    if (!_isConnected) throw Exception('Not connected to device');
    _currentVibration = intensity;
    notifyListeners();
  }
  
  @override
  Future<void> stopVibration() async {
    if (!_isConnected) throw Exception('Not connected to device');
    _currentVibration = 0.0;
    notifyListeners();
  }
  
  @override
  Future<List<String>> scanForDevices() async {
    return ['Mock Device 1', 'Mock Device 2', 'Mock Device 3'];
  }
  
  @override
  Future<void> connectToDevice(String deviceId) async {
    _currentDevice = deviceId;
    notifyListeners();
  }
  
  void setConnected(bool value) {
    if (value) {
      connect();
    } else {
      disconnect();
    }
  }
  
  // Implement other methods from MockButtplugService if needed
  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late MockWeb3Service mockWeb3Service;
  late TestButtplugService mockButtplugService;

  setUp(() {
    mockWeb3Service = MockWeb3Service();
    mockButtplugService = TestButtplugService();
  });

  tearDown(() {
    // Clean up any resources
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Web3Service>.value(value: mockWeb3Service),
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
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      // Check for the button in the body
      expect(find.text('Connect Wallet'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsWidgets);
      
      // Check for the icon in the app bar
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);
    });

    testWidgets('Shows connect device button when not connected',
        (WidgetTester tester) async {
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      // Connect Device button should be visible in the body when wallet is not connected
      expect(find.text('Connect Device'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsWidgets); // May find multiple instances
    });

    testWidgets('Shows wallet connected icon when wallet is connected',
        (WidgetTester tester) async {
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      // Should find wallet icon in the app bar and in the wallet management section
      expect(find.byIcon(Icons.account_balance_wallet), findsWidgets);
    });

    testWidgets('Shows device connected icon when device is connected',
        (WidgetTester tester) async {
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(true);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      expect(find.byIcon(Icons.bluetooth_connected), findsWidgets);
    });

    testWidgets('Can connect wallet by tapping connect button',
        (WidgetTester tester) async {
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      await tester.tap(find.text('Connect Wallet'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      // State should be updated after tapping
      expect(mockWeb3Service.isConnected, isTrue);
    });

    testWidgets('Can connect device by tapping connect button',
        (WidgetTester tester) async {
      // Set a larger viewport to avoid overflow
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      await tester.tap(find.text('Connect Device'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500)); // Wait for pending timers

      // State should be updated after tapping
      expect(mockButtplugService.isConnected, isTrue);
    });
  });
}
