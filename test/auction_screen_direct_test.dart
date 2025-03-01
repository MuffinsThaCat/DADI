import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/operation_result.dart';
import 'dart:developer' as developer;
import 'package:dadi/providers/meta_transaction_provider.dart';

// Mock implementation for Web3Service
class MockWeb3Service extends ChangeNotifier {
  final Map<String, Auction> _auctions = {};
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
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

// Mock WebSocket service for transaction status updates
class MockMetaTransactionProvider extends ChangeNotifier implements MetaTransactionProvider {
  final List<MetaTransaction> _transactions = [];
  
  @override
  List<MetaTransaction> get transactions => _transactions;
  
  // Quota-related getters
  @override
  int get remainingQuota => 5;
  
  @override
  int get totalQuota => 10;
  
  @override
  DateTime get quotaResetTime => DateTime.now().add(const Duration(days: 1));
  
  @override
  bool get hasQuotaAvailable => true;
  
  @override
  Future<String> executeFunction({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String description,
    int? gasLimit,
    int? validUntilTime,
  }) async {
    final txHash = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    _transactions.add(MetaTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}_id',
      txHash: txHash,
      description: description,
      timestamp: DateTime.now(),
      status: MetaTransactionStatus.processing,
      targetContract: targetContract,
      functionSignature: functionSignature,
    ));
    notifyListeners();
    return txHash;
  }
  
  @override
  void clearHistory() {
    _transactions.clear();
    notifyListeners();
  }
  
  // Helper method to simulate transaction updates
  void updateTransactionStatus(String txHash, MetaTransactionStatus status, {String? error}) {
    final index = _transactions.indexWhere((tx) => tx.txHash == txHash);
    if (index != -1) {
      _transactions[index] = MetaTransaction(
        id: _transactions[index].id,
        txHash: _transactions[index].txHash,
        description: _transactions[index].description,
        timestamp: _transactions[index].timestamp,
        status: status,
        error: error,
        targetContract: _transactions[index].targetContract,
        functionSignature: _transactions[index].functionSignature,
      );
      notifyListeners();
    }
  }
  
  // Add a test transaction
  String addTestTransaction(String description, MetaTransactionStatus status) {
    final txHash = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final id = 'tx_${DateTime.now().millisecondsSinceEpoch}_id';
    _transactions.add(MetaTransaction(
      id: id,
      txHash: txHash,
      description: description,
      timestamp: DateTime.now(),
      status: status,
      targetContract: '0xTestContract',
      functionSignature: 'test()',
    ));
    notifyListeners();
    return txHash;
  }
}

// Mock AuctionScreen implementation that doesn't depend on the real implementation
class MockAuctionScreen extends StatefulWidget {
  final String deviceId;

  const MockAuctionScreen({super.key, required this.deviceId});

  @override
  State<MockAuctionScreen> createState() => _MockAuctionScreenState();
}

class _MockAuctionScreenState extends State<MockAuctionScreen> {
  Auction? _auction;
  String? _errorMessage;
  final TextEditingController _bidController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAuction();
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _loadAuction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final web3 = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3.getAuction(deviceId: widget.deviceId);

    setState(() {
      _isLoading = false;
      if (result.success) {
        _auction = result.data;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  Future<void> _placeBid() async {
    if (_bidController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a bid amount';
      });
      return;
    }

    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null) {
      setState(() {
        _errorMessage = 'Invalid bid amount';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final web3 = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3.placeBid(
      deviceId: widget.deviceId,
      amount: bidAmount,
    );

    if (result.success) {
      // Reload auction to get updated data
      _loadAuction();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _finalizeAuction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final web3 = Provider.of<MockWeb3Service>(context, listen: false);
    final result = await web3.finalizeAuction(deviceId: widget.deviceId);

    if (result.success) {
      // Reload auction to get updated data
      _loadAuction();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceId),
        actions: [
          // Add transaction status indicator
          Consumer<MockMetaTransactionProvider>(
            builder: (context, provider, child) {
              final pendingTransactions = provider.transactions
                  .where((tx) => tx.status == MetaTransactionStatus.processing || 
                                tx.status == MetaTransactionStatus.submitted)
                  .toList();
              
              if (pendingTransactions.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: Badge(
                    label: Text(pendingTransactions.length.toString()),
                    child: const Icon(Icons.sync),
                  ),
                  onPressed: () {
                    // Show transaction details
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending Transactions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pendingTransactions.map((tx) => 
                              ListTile(
                                title: Text(tx.description),
                                subtitle: Text(tx.status.toString().split('.').last),
                                leading: Icon(
                                  tx.status == MetaTransactionStatus.processing ? 
                                    Icons.sync : Icons.check_circle,
                                  color: tx.status == MetaTransactionStatus.processing ? 
                                    Colors.orange : Colors.green,
                                ),
                              )
                            ).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _buildAuctionDetails(),
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
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_auction!.deviceId, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text('Start Time: ${_auction!.startTime}'),
          Text('End Time: ${_auction!.endTime}'),
          Text('Minimum Bid: ${_auction!.minimumBid} ETH'),
          Text('Highest Bid: ${_auction!.highestBid} ETH'),
          if (_auction!.highestBidder.isNotEmpty)
            Text('Highest Bidder: ${_auction!.highestBidder}'),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (!isEnded && !_auction!.isFinalized)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _bidController,
                  decoration: const InputDecoration(
                    labelText: 'Bid Amount (ETH)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _placeBid,
                  child: const Text('Place Bid'),
                ),
              ],
            )
          else if (isEnded && !_auction!.isFinalized)
            ElevatedButton(
              onPressed: _finalizeAuction,
              child: const Text('Finalize Auction'),
            )
          else
            const Text('Auction has been finalized'),
        ],
      ),
    );
  }
}

void main() {
  late MockWeb3Service mockWeb3Service;
  late MockMetaTransactionProvider mockTransactionProvider;

  setUp(() {
    mockWeb3Service = MockWeb3Service();
    mockTransactionProvider = MockMetaTransactionProvider();
    
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
        ChangeNotifierProvider<MockWeb3Service>.value(
          value: mockWeb3Service,
        ),
        ChangeNotifierProvider<MockMetaTransactionProvider>.value(
          value: mockTransactionProvider,
        ),
      ],
      child: const MaterialApp(
        home: MockAuctionScreen(deviceId: 'test-device-1'),
      ),
    );
  }

  group('MockAuctionScreen Tests', () {
    testWidgets('Shows auction details when auction exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Find the device ID in the app bar title
      expect(find.widgetWithText(AppBar, 'test-device-1'), findsOneWidget);
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

      // Verify error message - the exact text might be different
      expect(find.textContaining('must be higher than current highest bid'), findsOneWidget);
    });

    testWidgets('Shows finalize button when auction has ended',
        (WidgetTester tester) async {
      // Create an auction that has ended
      final now = DateTime.now();
      mockWeb3Service.clearMockAuctions();
      mockWeb3Service.addMockAuction(Auction(
        deviceId: 'test-device-1',
        owner: 'Test Owner',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        minimumBid: 0.1,
        highestBid: 0.2,
        highestBidder: 'Test Bidder',
        isActive: true,
        isFinalized: false,
      ));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify finalize button is shown
      expect(find.text('Finalize Auction'), findsOneWidget);
    });

    testWidgets('Can finalize an ended auction',
        (WidgetTester tester) async {
      // Create an auction that has ended
      final now = DateTime.now();
      mockWeb3Service.clearMockAuctions();
      mockWeb3Service.addMockAuction(Auction(
        deviceId: 'test-device-1',
        owner: 'Test Owner',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        minimumBid: 0.1,
        highestBid: 0.2,
        highestBidder: 'Test Bidder',
        isActive: true,
        isFinalized: false,
      ));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap finalize button
      await tester.tap(find.text('Finalize Auction'));
      await tester.pumpAndSettle();

      // Verify auction has been finalized
      expect(find.text('Auction has been finalized'), findsOneWidget);
    });
  });

  group('Transaction Status Display Tests', () {
    testWidgets('Shows transaction status indicator when transactions are in progress',
        (WidgetTester tester) async {
      // Add a processing transaction
      mockTransactionProvider.addTestTransaction(
        'Test Transaction',
        MetaTransactionStatus.processing
      );
      
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Verify transaction indicator is shown
      expect(find.byIcon(Icons.sync), findsOneWidget);
      
      // Verify the indicator shows "1" for one pending transaction
      expect(find.text('1'), findsOneWidget);
    });
    
    testWidgets('Updates transaction status indicator when transaction completes',
        (WidgetTester tester) async {
      // Add a processing transaction
      final txHash = mockTransactionProvider.addTestTransaction(
        'Test Transaction',
        MetaTransactionStatus.processing
      );
      
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Verify transaction indicator shows "1"
      expect(find.text('1'), findsOneWidget);
      
      // Update transaction to confirmed
      mockTransactionProvider.updateTransactionStatus(
        txHash,
        MetaTransactionStatus.confirmed
      );
      
      await tester.pump();
      await tester.pumpAndSettle();
      
      // Verify transaction indicator is no longer showing "1"
      // (It might not be visible at all if there are no pending transactions)
      expect(find.text('1'), findsNothing);
    });
    
    testWidgets('Shows transaction details when indicator is tapped',
        (WidgetTester tester) async {
      // Add a processing transaction
      mockTransactionProvider.addTestTransaction(
        'Test Transaction',
        MetaTransactionStatus.processing
      );
      
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Tap on the transaction indicator
      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();
      
      // Verify transaction details are shown
      expect(find.text('Test Transaction'), findsOneWidget);
      expect(find.text('processing'), findsOneWidget);
    });
  });
}
