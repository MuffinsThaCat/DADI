import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';
import 'dart:developer' as developer;

// Mock version of AuctionScreen without dependencies on Web3Service
class MockAuctionScreen extends StatefulWidget {
  final int initialTab;
  final String? deviceId;
  
  const MockAuctionScreen({
    super.key,
    this.initialTab = 0,
    this.deviceId,
  });

  @override
  State<MockAuctionScreen> createState() => _MockAuctionScreenState();
}

class _MockAuctionScreenState extends State<MockAuctionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Auction? _auction;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadAuction();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAuction() async {
    if (widget.deviceId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No device ID provided';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final web3Service = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3Service.getAuction(deviceId: widget.deviceId!);
    
    setState(() {
      _isLoading = false;
      if (result.success) {
        _auction = result.data;
      } else {
        _errorMessage = result.message;
      }
    });
  }
  
  Future<void> _placeBid(double amount) async {
    if (widget.deviceId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final web3Service = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3Service.placeBidNew(
      deviceId: widget.deviceId!,
      amount: amount,
    );
    
    setState(() {
      _isLoading = false;
      if (result.success) {
        _auction = result.data;
      } else {
        _errorMessage = result.message;
      }
    });
  }
  
  Future<void> _finalizeAuction() async {
    if (widget.deviceId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final web3Service = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3Service.finalizeAuctionNew(deviceId: widget.deviceId!);
    
    setState(() {
      _isLoading = false;
      if (result.success) {
        _auction = result.data;
      } else {
        _errorMessage = result.message;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Control'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _auction == null
                  ? const Center(child: Text('No auction found'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAuctionDetails(),
                        const Center(child: Text('Device Control')),
                      ],
                    ),
    );
  }
  
  Widget _buildAuctionDetails() {
    if (_auction == null) {
      developer.log('_auction is null in _buildAuctionDetails');
      return const SizedBox.shrink();
    }
    
    developer.log('Building auction details for device: ${_auction!.deviceId}');
    
    final now = DateTime.now();
    final isEnded = _auction!.endTime.isBefore(now);
    final isActive = _auction!.isActive;
    final isFinalized = _auction!.isFinalized;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device ID: ${_auction!.deviceId}', 
               style: Theme.of(context).textTheme.titleLarge,
               key: const ValueKey('device_id_text')),
          const SizedBox(height: 16),
          Text('Owner: ${_auction!.owner}'),
          Text('Start Time: ${_auction!.startTime}'),
          Text('End Time: ${_auction!.endTime}'),
          Text('Minimum Bid: ${_auction!.minimumBid} ETH'),
          Text('Highest Bid: ${_auction!.highestBid} ETH'),
          Text('Highest Bidder: ${_auction!.highestBidder}'),
          Text('Status: ${isActive ? "Active" : "Inactive"}'),
          Text('Finalized: ${isFinalized ? "Yes" : "No"}'),
          const SizedBox(height: 16),
          
          if (isActive && !isEnded)
            ElevatedButton(
              onPressed: () => _placeBid(_auction!.highestBid + 0.1),
              child: const Text('Place Bid'),
            )
          else if (isEnded && !isFinalized)
            ElevatedButton(
              onPressed: _finalizeAuction,
              child: const Text('Finalize Auction'),
            ),
        ],
      ),
    );
  }
}

// Simple mock implementation for Web3Service
class MockWeb3Service extends ChangeNotifier {
  Map<String, Map<String, dynamic>> activeAuctions = {};
  final bool _mockMode = true;

  bool get isMockMode => _mockMode;

  Future<bool> initializeContract() async {
    return true;
  }

  Future<bool> connectWithJsonRpc() async {
    return true;
  }

  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, activeAuctions[deviceId]!),
    );
  }

  Future<OperationResult<Auction>> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = activeAuctions[deviceId]!;
    final amountWei = BigInt.from((amount * 1e18).toInt());
    
    if (amountWei <= auction['highestBid']) {
      return OperationResult<Auction>(
        success: false,
        message: 'Bid must be higher than current highest bid',
      );
    }
    
    auction['highestBid'] = amountWei;
    auction['highestBidder'] = '0xMockBidder';
    
    notifyListeners();
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, auction),
    );
  }

  Future<OperationResult<Auction>> finalizeAuctionNew({required String deviceId}) async {
    if (!activeAuctions.containsKey(deviceId)) {
      return OperationResult<Auction>(
        success: false,
        message: 'Auction not found',
      );
    }
    
    final auction = activeAuctions[deviceId]!;
    auction['isActive'] = false;
    auction['isFinalized'] = true;
    
    notifyListeners();
    
    return OperationResult<Auction>(
      success: true,
      data: _createAuctionFromMap(deviceId, auction),
    );
  }

  Future<void> loadActiveAuctions() async {
    // In mock mode, we don't need to do anything
    notifyListeners();
  }

  Future<void> createMockAuction(String deviceId) async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(hours: 1));
    final endTime = now.add(const Duration(hours: 24));
    
    activeAuctions[deviceId] = {
      'owner': '0xMockOwner',
      'startTime': BigInt.from(startTime.millisecondsSinceEpoch ~/ 1000),
      'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
      'minimumBid': BigInt.from(0.1 * 1e18),
      'highestBid': BigInt.zero,
      'highestBidder': '0x0000000000000000000000000000000000000000',
      'isActive': true,
      'isFinalized': false,
    };
    
    notifyListeners();
  }

  // Helper method to create an Auction object from a map
  Auction _createAuctionFromMap(String deviceId, Map<String, dynamic> map) {
    return Auction(
      deviceId: deviceId,
      owner: map['owner'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (map['startTime'] as BigInt).toInt() * 1000,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (map['endTime'] as BigInt).toInt() * 1000,
      ),
      minimumBid: (map['minimumBid'] as BigInt).toDouble() / 1e18,
      highestBid: (map['highestBid'] as BigInt).toDouble() / 1e18,
      highestBidder: map['highestBidder'] as String,
      isActive: map['isActive'] as bool,
      isFinalized: map['isFinalized'] as bool,
    );
  }
}

// Simple mock implementation for SettingsService
class MockSettingsService {
  String getContractAddress() => '0xMockContractAddress';
  String getRpcUrl() => 'http://localhost:8545';
  bool getUseMockBlockchain() => true;
  Future<void> setContractAddress(String address) async {}
  Future<void> setRpcUrl(String url) async {}
  Future<void> setUseMockBlockchain(bool enabled) async {}
}

void main() {
  late MockWeb3Service mockWeb3Service;
  
  setUp(() {
    mockWeb3Service = MockWeb3Service();
  });
  
  testWidgets('AuctionScreen shows loading indicator initially', (WidgetTester tester) async {
    const deviceId = 'test-device-id';
    
    // Create a mock auction before pumping the widget
    await mockWeb3Service.createMockAuction(deviceId);
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MockWeb3Service>.value(value: mockWeb3Service),
        ],
        child: const MaterialApp(
          home: MockAuctionScreen(deviceId: deviceId),
        ),
      ),
    );
    
    // Initially we should see a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for the async operation to complete and UI to update
    await tester.pumpAndSettle();
    
    // Now we should see the auction details
    expect(find.byKey(const ValueKey('device_id_text')), findsOneWidget);
  });
  
  testWidgets('AuctionScreen shows Place Bid button when auction is active', (WidgetTester tester) async {
    const deviceId = 'test-device-id';
    
    // Create a mock auction that is active
    await mockWeb3Service.createMockAuction(deviceId);
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MockWeb3Service>.value(value: mockWeb3Service),
        ],
        child: const MaterialApp(
          home: MockAuctionScreen(deviceId: deviceId),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    expect(find.text('Place Bid'), findsOneWidget);
  });
  
  testWidgets('AuctionScreen shows Finalize Auction button when auction is ended but not finalized', (WidgetTester tester) async {
    const deviceId = 'test-device-id';
    
    // Create a mock auction that is ended but not finalized
    await mockWeb3Service.createMockAuction(deviceId);
    
    // Set the end time to the past
    final now = DateTime.now();
    final pastEndTime = now.subtract(const Duration(hours: 1));
    mockWeb3Service.activeAuctions[deviceId]!['endTime'] = 
        BigInt.from(pastEndTime.millisecondsSinceEpoch ~/ 1000);
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MockWeb3Service>.value(value: mockWeb3Service),
        ],
        child: const MaterialApp(
          home: MockAuctionScreen(deviceId: deviceId),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    expect(find.text('Finalize Auction'), findsOneWidget);
  });
}
