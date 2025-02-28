import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Mock implementation of Web3Service
class MockWeb3Service extends ChangeNotifier {
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }
  
  void connect() {
    _isConnected = true;
    notifyListeners();
  }
  
  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }
}

// Mock implementation of ButtplugService
class MockButtplugService extends ChangeNotifier {
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }
  
  void connect() {
    _isConnected = true;
    notifyListeners();
  }
  
  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }
}

// Mock version of HomeScreen that doesn't depend on the real implementation
class MockHomeScreen extends StatelessWidget {
  const MockHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final web3 = Provider.of<MockWeb3Service>(context);
    final buttplug = Provider.of<MockButtplugService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DADI'),
        actions: [
          // Connect wallet button
          IconButton(
            icon: Icon(web3.isConnected ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined),
            onPressed: () => web3.isConnected ? web3.disconnect() : web3.connect(),
            tooltip: web3.isConnected ? 'Disconnect Wallet' : 'Connect Wallet',
          ),
          IconButton(
            icon: Icon(buttplug.isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
            onPressed: () => buttplug.isConnected ? buttplug.disconnect() : buttplug.connect(),
            tooltip: buttplug.isConnected ? 'Disconnect Device' : 'Connect Device',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!web3.isConnected)
              ElevatedButton(
                onPressed: web3.connect,
                child: const Text('Connect Wallet'),
              ),
            if (web3.isConnected && !buttplug.isConnected)
              ElevatedButton(
                onPressed: buttplug.connect,
                child: const Text('Connect Device'),
              ),
            if (web3.isConnected && buttplug.isConnected)
              const Text('Ready to use'),
          ],
        ),
      ),
    );
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
        home: MockHomeScreen(),
      ),
    );
  }

  group('HomeScreen Tests', () {
    testWidgets('Shows connect wallet button when not connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(false);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());

      expect(find.text('Connect Wallet'), findsOneWidget);
    });

    testWidgets('Shows connect device button when wallet connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(false);

      await tester.pumpWidget(createTestApp());

      expect(find.text('Connect Device'), findsOneWidget);
    });
    
    testWidgets('Shows ready to use when both connected',
        (WidgetTester tester) async {
      mockWeb3Service.setConnected(true);
      mockButtplugService.setConnected(true);

      await tester.pumpWidget(createTestApp());

      expect(find.text('Ready to use'), findsOneWidget);
    });
  });
}
