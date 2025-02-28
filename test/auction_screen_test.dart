@TestOn('browser')
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/screens/auction_screen.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';

// Improved mock implementation for Web3Service
class MockWeb3Service extends ChangeNotifier {
  Map<String, Auction> _auctions = {};
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  Future<bool> initializeContract() async {
    return true;
  }

  Future<bool> connectWithJsonRpc() async {
    _isConnected = true;
    notifyListeners();
    return true;
  }

  // Add a test auction
  void addMockAuction(Auction auction) {
    _auctions[auction.deviceId] = auction;
    notifyListeners();
  }

  // Clear all auctions
  void clearMockAuctions() {
    _auctions.clear();
    notifyListeners();
  }

  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    return OperationResult<Auction>(
      success: true,
      data: _auctions[deviceId],
    );
  }

  Future<OperationResult<List<Auction>>> getActiveAuctions() async {
    return OperationResult<List<Auction>>(
      success: true,
      data: _auctions.values.toList(),
    );
  }

  Future<OperationResult<bool>> placeBid({
    required String deviceId,
    required double amount,
  }) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction not found',
      );
    }

    final auction = _auctions[deviceId]!;
    
    if (auction.endTime.isBefore(DateTime.now())) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction has ended',
      );
    }

    if (amount <= auction.highestBid) {
      return OperationResult<bool>(
        success: false,
        message: 'Bid amount must be higher than current highest bid',
      );
    }

    // Update auction with new bid
    _auctions[deviceId] = Auction(
      deviceId: auction.deviceId,
      owner: auction.owner,
      startTime: auction.startTime,
      endTime: auction.endTime,
      minimumBid: auction.minimumBid,
      highestBid: amount,
      highestBidder: 'Test Bidder',
      isActive: auction.isActive,
      isFinalized: auction.isFinalized,
    );
    
    notifyListeners();
    
    return OperationResult<bool>(
      success: true,
      data: true,
    );
  }

  Future<OperationResult<bool>> finalizeAuction({required String deviceId}) async {
    if (!_auctions.containsKey(deviceId)) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction not found',
      );
    }

    final auction = _auctions[deviceId]!;
    
    if (!auction.endTime.isBefore(DateTime.now())) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction has not ended yet',
      );
    }

    if (auction.isFinalized) {
      return OperationResult<bool>(
        success: false,
        message: 'Auction already finalized',
      );
    }

    // Update auction to finalized state
    _auctions[deviceId] = Auction(
      deviceId: auction.deviceId,
      owner: auction.owner,
      startTime: auction.startTime,
      endTime: auction.endTime,
      minimumBid: auction.minimumBid,
      highestBid: auction.highestBid,
      highestBidder: auction.highestBidder,
      isActive: false,
      isFinalized: true,
    );
    
    notifyListeners();
    
    return OperationResult<bool>(
      success: true,
      data: true,
    );
  }
}

// Improved mock implementation for SettingsService
class MockSettingsService extends ChangeNotifier {
  String _contractAddress = '0x1234567890123456789012345678901234567890';
  String _rpcUrl = 'https://example.com/rpc';
  bool _useMockBlockchain = true;

  String getContractAddress() => _contractAddress;
  String getRpcUrl() => _rpcUrl;
  bool getUseMockBlockchain() => _useMockBlockchain;

  void setContractAddress(String address) {
    _contractAddress = address;
    notifyListeners();
  }

  void setRpcUrl(String url) {
    _rpcUrl = url;
    notifyListeners();
  }

  void setUseMockBlockchain(bool enabled) {
    _useMockBlockchain = enabled;
    notifyListeners();
  }
}

void main() {
  late MockWeb3Service mockWeb3Service;
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockWeb3Service = MockWeb3Service();
    mockSettingsService = MockSettingsService();
    
    // Add a test auction
    final now = DateTime.now();
    mockWeb3Service.addMockAuction(Auction(
      deviceId: 'test-device-1',
      owner: 'Test Owner',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 1)),
      minimumBid: 0.1,
      highestBid: 0.1,
      highestBidder: '',
      isActive: true,
      isFinalized: false,
    ));
  });

  tearDown(() {
    mockWeb3Service.clearMockAuctions();
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MockWeb3Service>.value(value: mockWeb3Service),
        ChangeNotifierProvider<MockSettingsService>.value(value: mockSettingsService),
      ],
      child: const MaterialApp(
        home: AuctionScreen(deviceId: 'test-device-1'),
      ),
    );
  }

  group('AuctionScreen Tests', () {
    testWidgets('Shows auction details when auction exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('test-device-1'), findsOneWidget);
      expect(find.text('Place Bid'), findsOneWidget);
    });

    testWidgets('Can place a bid on an active auction',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Enter bid amount
      await tester.enterText(find.byType(TextField), '0.2');
      
      // Tap place bid button
      await tester.tap(find.text('Place Bid'));
      await tester.pumpAndSettle();

      // Verify bid was placed
      expect(find.text('Highest Bid: 0.2 ETH'), findsOneWidget);
      expect(find.text('Highest Bidder: Test Bidder'), findsOneWidget);
    });

    testWidgets('Shows error when bid is too low',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Enter bid amount that's too low
      await tester.enterText(find.byType(TextField), '0.05');
      
      // Tap place bid button
      await tester.tap(find.text('Place Bid'));
      await tester.pumpAndSettle();

      // Verify error message
      expect(find.text('Bid amount must be higher than current highest bid'), findsOneWidget);
    });
  });
}
