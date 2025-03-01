import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import '../models/auction.dart';
import '../providers/mock_auction_provider.dart';
import '../providers/meta_transaction_provider.dart';
import 'device_control_screen.dart';
import '../widgets/wavy_background.dart'; // Import wavy background
import '../widgets/transaction_status_widget.dart';

class AuctionScreen extends StatefulWidget {
  final int initialTab;
  final String? deviceId;
  
  const AuctionScreen({
    super.key,
    this.initialTab = 0,
    this.deviceId,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 24));
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _minBidController = TextEditingController();
  final TextEditingController _totalTimePeriodController = TextEditingController();
  List<MetaTransaction> _pendingTransactions = [];
  final Set<String> _shownCompletionNotifications = {};
  // Add a scroll controller for the auctions list
  final ScrollController _auctionsScrollController = ScrollController();

  /// Log a message with the AuctionScreen prefix
  void _log(String message) {
    developer.log('AuctionScreen: $message');
  }

  @override
  void initState() {
    super.initState();
    _log('AuctionScreen initState');
    
    // Check if we're in mock mode and force create auctions if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndCreateMockAuctions();
    });
    
    _startDateController.text = _formatDateTime(_startDate);
    _endDateController.text = _formatDateTime(_endDate);
    _minBidController.text = '0.01';
    _totalTimePeriodController.text = '24';
    
    // Delay to ensure provider is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePendingTransactions();
      
      // If a specific deviceId is provided, scroll to it after the auctions are loaded
      if (widget.deviceId != null) {
        _scrollToHighlightedAuction();
      }
    });
  }

  void _updatePendingTransactions() {
    final metaTxProvider = Provider.of<MetaTransactionProvider>(context, listen: false);
    setState(() {
      // Only track transactions that are still in progress
      _pendingTransactions = metaTxProvider.transactions
          .where((tx) => tx.status == MetaTransactionStatus.submitted || 
                         tx.status == MetaTransactionStatus.processing)
          .toList();
    });
    
    // If there are any newly confirmed or failed transactions, show a brief toast
    final recentlyCompleted = metaTxProvider.transactions
        .where((tx) => (tx.status == MetaTransactionStatus.confirmed || 
                       tx.status == MetaTransactionStatus.failed) &&
                       DateTime.now().difference(tx.timestamp).inMinutes < 2)
        .toList();
        
    for (final tx in recentlyCompleted) {
      if (!_shownCompletionNotifications.contains(tx.id)) {
        _shownCompletionNotifications.add(tx.id);
        
        // Show a brief toast for the completed transaction
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tx.status == MetaTransactionStatus.confirmed
                ? 'Transaction completed: ${tx.description}'
                : 'Transaction failed: ${tx.description}',
            ),
            backgroundColor: tx.status == MetaTransactionStatus.confirmed
                ? Colors.green
                : Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // Method to scroll to the highlighted auction
  void _scrollToHighlightedAuction() {
    if (widget.deviceId == null) return;
    
    // Delay to ensure the list is built
    Future.delayed(const Duration(milliseconds: 500), () {
      final web3 = Provider.of<Web3Service>(context, listen: false);
      final auctions = web3.activeAuctions;
      
      // Find the index of the auction with the matching deviceId
      final auctionsList = auctions.keys.toList();
      final index = auctionsList.indexOf(widget.deviceId!);
      
      if (index != -1 && _auctionsScrollController.hasClients) {
        // Calculate the position to scroll to
        final itemHeight = 200.0; // Approximate height of each auction card
        final offset = index * itemHeight;
        
        // Scroll to the position
        _auctionsScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Check if we're in mock mode and create mock auctions if needed
  void _checkAndCreateMockAuctions() async {
    // Use Future.microtask to avoid calling setState during build
    Future.microtask(() async {
      final web3Service = context.read<Web3Service>();
      
      if (web3Service.isMockMode) {
        _log('Mock mode detected, ensuring mock auctions exist');
        
        // Get current auctions
        final result = await web3Service.getActiveAuctions();
        
        if (!result.success || (result.data?.isEmpty ?? true)) {
          _log('No active auctions found in mock mode, forcing mock auctions creation');
          await web3Service.forceEnableMockMode();
          
          // Refresh the UI
          if (mounted) {
            _refreshAuctions();
          }
        } else {
          _log('Mock auctions already exist: ${result.data?.length ?? 0}');
        }
      }
    });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _minBidController.dispose();
    _totalTimePeriodController.dispose();
    _auctionsScrollController.dispose(); // Dispose the scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web3 = Provider.of<Web3Service>(context);
    final buttplug = Provider.of<MockButtplugService>(context);
    final metaTxProvider = Provider.of<MetaTransactionProvider>(context);
    final theme = Theme.of(context);
    final isConnected = web3.isConnected;
    final isMockMode = web3.isMockMode;

    // Update pending transactions when provider changes
    if (_pendingTransactions.length != metaTxProvider.transactions
        .where((tx) => tx.status == MetaTransactionStatus.submitted || 
                       tx.status == MetaTransactionStatus.processing)
        .length) {
      _updatePendingTransactions();
    }

    return DefaultTabController(
      length: 2,
      // If a deviceId is provided, select the Active Auctions tab
      initialIndex: widget.deviceId != null ? 1 : widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DADI Auctions'),
          actions: [
            // Network status indicator
            Tooltip(
              message: isMockMode 
                  ? 'Running in mock mode (no blockchain)' 
                  : isConnected 
                      ? 'Connected to blockchain' 
                      : 'Not connected to blockchain',
              child: IconButton(
                icon: Icon(
                  isMockMode 
                      ? Icons.cloud_off 
                      : isConnected 
                          ? Icons.cloud_done 
                          : Icons.cloud_off,
                  color: isMockMode 
                      ? Colors.orange 
                      : isConnected 
                          ? Colors.green 
                          : Colors.red,
                ),
                onPressed: _showNetworkStatus,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshAuctions,
              tooltip: 'Refresh auctions',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create Auction'),
              Tab(text: 'Active Auctions'),
            ],
          ),
        ),
        body: WavyBackground(
          primaryColor: theme.colorScheme.primary,
          secondaryColor: theme.colorScheme.secondary,
          child: TabBarView(
            children: [
              _buildCreateAuctionTab(web3, buttplug),
              _buildActiveAuctionsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAuctionTab(Web3Service web3, MockButtplugService buttplug) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Device',
                border: OutlineInputBorder(),
              ),
              value: buttplug.currentDevice,
              items: ['Mock Device 1', 'Mock Device 2', 'Mock Device 3']
                  .map((device) => DropdownMenuItem(
                        value: device,
                        child: Text(device),
                      ))
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                  await buttplug.connectToDevice(value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startDateController,
              decoration: const InputDecoration(
                labelText: 'Start Date',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a start date';
                }
                try {
                  DateTime.parse(value);
                  return null;
                } catch (e) {
                  return 'Invalid date format';
                }
              },
              onChanged: (value) {
                try {
                  _startDate = DateTime.parse(value);
                  // Update end date based on total time period
                  _updateEndDate();
                } catch (e) {
                  // Invalid date format, ignore
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _endDateController,
              decoration: const InputDecoration(
                labelText: 'End Date (calculated)',
                hintText: 'Based on start date and total time',
              ),
              readOnly: true, // Make it read-only
              enabled: false, // Disable the field
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an end date';
                }
                try {
                  final endDate = DateTime.parse(value);
                  if (endDate.isBefore(_startDate)) {
                    return 'End date must be after start date';
                  }
                  return null;
                } catch (e) {
                  return 'Invalid date format';
                }
              },
              onChanged: (value) {
                try {
                  _endDate = DateTime.parse(value);
                } catch (e) {
                  // Invalid date format, ignore
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalTimePeriodController,
              decoration: const InputDecoration(
                labelText: 'Total Time Period (hours)',
                hintText: 'Enter total hours for device usage',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter total time period';
                }
                final hours = int.tryParse(value);
                if (hours == null || hours <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
              onChanged: (value) {
                if (value.isNotEmpty && int.tryParse(value) != null) {
                  _updateEndDate();
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Minimum Bid (ETH)',
                border: OutlineInputBorder(),
              ),
              controller: _minBidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a minimum bid';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });

                        try {
                          // Check if web3 is connected
                          if (!web3.isConnected) {
                            throw Exception('Wallet not connected. Please connect your wallet first.');
                          }
                          
                          // Check if contract is initialized
                          if (!web3.isContractInitialized) {
                            await web3.initializeContract();
                            if (!web3.isContractInitialized) {
                              throw Exception('Failed to initialize contract. Please try again.');
                            }
                          }
                          
                          // Validate contract with a test call
                          bool isValid = await web3.testContract();
                          if (!isValid) {
                            _errorMessage = 'Contract validation failed. Please check your connection and try again.';
                            _isLoading = false;
                            if (mounted) {
                              setState(() {});
                            }
                            return;
                          }
                          
                          final deviceId = buttplug.currentDevice;
                          if (deviceId == null) {
                            // Use a mock device ID if no device is selected
                            final mockDeviceId = 'mock_device_${DateTime.now().millisecondsSinceEpoch}';
                            _log('No device selected, using mock device ID: $mockDeviceId');
                            
                            // Convert form values to appropriate types
                            final minBidEth = double.parse(_minBidController.text);
                            final totalTimePeriod = int.parse(_totalTimePeriodController.text);
                            
                            _log('Creating auction with params:');
                            _log('Device ID: $mockDeviceId');
                            _log('Start Date: $_startDate');
                            _log('End Date: $_endDate');
                            _log('Min Bid: $minBidEth ETH');
                            _log('Total Time Period: $totalTimePeriod hours');
                            
                            // Call the contract method with mock device ID
                            try {
                              if (kIsWeb) {
                                // Use MockAuctionProvider for web
                                final mockAuctionProvider = context.read<MockAuctionProvider?>();
                                if (mockAuctionProvider != null) {
                                  _log('Using MockAuctionProvider for web to create auction');
                                  final success = await mockAuctionProvider.createAuction(
                                    deviceId: mockDeviceId,
                                    startTime: _startDate,
                                    duration: Duration(hours: totalTimePeriod),
                                    minimumBid: minBidEth,
                                  );
                                  
                                  if (mounted) {
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Auction created successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Failed to create auction. Device ID may already exist.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Fall back to Web3Service
                                  await web3.createAuction(
                                    deviceId: mockDeviceId,
                                    startTime: _startDate,
                                    duration: Duration(hours: totalTimePeriod),
                                    minimumBid: minBidEth,
                                  );
                                }
                              } else {
                                // Use Web3Service for non-web platforms
                                await web3.createAuction(
                                  deviceId: mockDeviceId,
                                  startTime: _startDate,
                                  duration: Duration(hours: totalTimePeriod),
                                  minimumBid: minBidEth,
                                );
                              }
                              
                              if (mounted && !kIsWeb) {
                                // Check if we've switched to mock mode during the process
                                if (web3.isMockMode) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Created mock auction due to blockchain connection issues'),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Auction created successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              handleAuctionCreationError(e);
                            }
                          } else {
                            // Original code for when a device is selected
                            // Convert form values to appropriate types
                            final minBidEth = double.parse(_minBidController.text);
                            final totalTimePeriod = int.parse(_totalTimePeriodController.text);
                            
                            _log('Creating auction with params:');
                            _log('Device ID: $deviceId');
                            _log('Start Date: $_startDate');
                            _log('End Date: $_endDate');
                            _log('Min Bid: $minBidEth ETH');
                            _log('Total Time Period: $totalTimePeriod hours');
                            
                            // Call the contract method
                            try {
                              if (kIsWeb) {
                                // Use MockAuctionProvider for web
                                final mockAuctionProvider = context.read<MockAuctionProvider?>();
                                if (mockAuctionProvider != null) {
                                  _log('Using MockAuctionProvider for web to create auction with real device');
                                  final success = await mockAuctionProvider.createAuction(
                                    deviceId: deviceId,
                                    startTime: _startDate,
                                    duration: Duration(hours: totalTimePeriod),
                                    minimumBid: minBidEth,
                                  );
                                  
                                  if (mounted) {
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Auction created successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Failed to create auction. Device ID may already exist.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Fall back to Web3Service
                                  await web3.createAuction(
                                    deviceId: deviceId,
                                    startTime: _startDate,
                                    duration: Duration(hours: totalTimePeriod),
                                    minimumBid: minBidEth,
                                  );
                                }
                              } else {
                                // Use Web3Service for non-web platforms
                                await web3.createAuction(
                                  deviceId: deviceId,
                                  startTime: _startDate,
                                  duration: Duration(hours: totalTimePeriod),
                                  minimumBid: minBidEth,
                                );
                              }
                              
                              if (mounted && !kIsWeb) {
                                // Check if we've switched to mock mode during the process
                                if (web3.isMockMode) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Created mock auction due to blockchain connection issues'),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Auction created successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              handleAuctionCreationError(e);
                            }
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Auction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAuctionsTab() {
    final web3Service = context.watch<Web3Service>();
    
    // In web mode, use the MockAuctionProvider if available
    if (kIsWeb) {
      final mockAuctionProvider = context.watch<MockAuctionProvider?>();
      if (mockAuctionProvider != null) {
        _log('Using MockAuctionProvider for web');
        final auctions = mockAuctionProvider.auctions;
        
        if (auctions.isEmpty) {
          return const Center(
            child: Text('No active auctions found'),
          );
        }
        
        return ListView.builder(
          itemCount: auctions.length,
          itemBuilder: (context, index) {
            final auction = auctions[index];
            return _buildAuctionCard(auction, web3Service);
          },
        );
      }
    }
    
    return RefreshIndicator(
      onRefresh: _refreshAuctions,
      child: Column(
        children: [
          // Compact transaction status indicator for pending transactions only
          if (_pendingTransactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _pendingTransactions.length == 1
                        ? '1 transaction in progress'
                        : '${_pendingTransactions.length} transactions in progress',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
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
                              ..._pendingTransactions.map((tx) => 
                                TransactionStatusWidget(
                                  transaction: tx,
                                  compact: false,
                                )
                              ).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Details', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage'))
                    : FutureBuilder(
                        future: web3Service.loadActiveAuctions(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return ListView.builder(
                              controller: _auctionsScrollController, // Use the scroll controller
                              itemCount: web3Service.activeAuctions.length,
                              itemBuilder: (context, index) {
                                final deviceId = web3Service.activeAuctions.keys.elementAt(index);
                                final auction = web3Service.activeAuctions[deviceId]!;
                                
                                // Skip if auction data is invalid
                                if (auction['endTime'] == null) {
                                  return const SizedBox.shrink();
                                }
                                
                                final now = DateTime.now();
                                // Handle different endTime formats safely
                                DateTime endTime;
                                if (auction['endTime'] is BigInt) {
                                  // Handle BigInt format
                                  final endTimeBigInt = auction['endTime'] as BigInt;
                                  endTime = DateTime.fromMillisecondsSinceEpoch(
                                    (endTimeBigInt.toInt() * 1000)
                                  );
                                } else if (auction['endTime'] is DateTime) {
                                  // Handle DateTime format directly
                                  endTime = auction['endTime'] as DateTime;
                                } else if (auction['endTime'] is int) {
                                  // Handle int format (seconds since epoch)
                                  final endTimeInt = auction['endTime'] as int;
                                  endTime = DateTime.fromMillisecondsSinceEpoch(endTimeInt * 1000);
                                } else {
                                  // Fallback to current time plus 1 hour if format is unknown
                                  endTime = DateTime.now().add(const Duration(hours: 1));
                                  developer.log('Unknown endTime format: ${auction['endTime']}');
                                }
                                final hasEnded = now.isAfter(endTime);
                                
                                // Safely handle all auction data fields with null checks and type conversions
                                final isActive = auction['active'] is bool ? auction['active'] as bool : false;
                                final isFinalized = auction['finalized'] is bool ? auction['finalized'] as bool : false;
                                
                                // Handle highestBidder safely
                                final String? highestBidder = auction['highestBidder'] is String ? auction['highestBidder'] as String : null;
                                final hasControl = highestBidder != null && highestBidder == web3Service.currentAddress;
                                
                                // Handle owner safely
                                final String owner = auction['owner'] is String ? auction['owner'] as String : 'Unknown';
                                
                                // Handle highestBid safely
                                BigInt highestBid;
                                try {
                                  if (auction['highestBid'] is BigInt) {
                                    highestBid = auction['highestBid'] as BigInt;
                                  } else if (auction['highestBid'] is int) {
                                    highestBid = BigInt.from(auction['highestBid'] as int);
                                  } else if (auction['highestBid'] is String) {
                                    highestBid = BigInt.parse(auction['highestBid'] as String);
                                  } else {
                                    highestBid = BigInt.zero;
                                    developer.log('Unknown highestBid format: ${auction['highestBid']}');
                                  }
                                } catch (e) {
                                  highestBid = BigInt.zero;
                                  developer.log('Error parsing highestBid: $e');
                                }
                                
                                // Handle minBid safely
                                BigInt minBid;
                                try {
                                  if (auction['minBid'] is BigInt) {
                                    minBid = auction['minBid'] as BigInt;
                                  } else if (auction['minBid'] is int) {
                                    minBid = BigInt.from(auction['minBid'] as int);
                                  } else if (auction['minBid'] is String) {
                                    minBid = BigInt.parse(auction['minBid'] as String);
                                  } else {
                                    minBid = BigInt.zero;
                                    developer.log('Unknown minBid format: ${auction['minBid']}');
                                  }
                                } catch (e) {
                                  minBid = BigInt.zero;
                                  developer.log('Error parsing minBid: $e');
                                }

                                // Check if this is the auction we should highlight
                                final isHighlighted = widget.deviceId != null && deviceId == widget.deviceId;

                                return Card(
                                  margin: const EdgeInsets.all(8.0),
                                  // Highlight the card if it matches the deviceId parameter
                                  color: isHighlighted ? Colors.amber.shade50 : null,
                                  shape: isHighlighted 
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.amber.shade700, width: 2),
                                      )
                                    : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Device ID: ${deviceId.substring(0, 10)}...'),
                                        Text('Owner: ${_formatAddress(owner)}'),
                                        Text('End Time: ${_formatDateTime(endTime)}'),
                                        Text('Minimum Bid: ${_formatEther(minBid)} ETH'),
                                        if (highestBid > BigInt.zero && highestBidder != null)
                                          Text(
                                            'Current Bid: ${_formatEther(highestBid)} ETH by ${_formatAddress(highestBidder)}',
                                          ),
                                        const SizedBox(height: 8),
                                        // Status indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive 
                                                ? Colors.green.shade100 
                                                : (isFinalized ? Colors.blue.shade100 : Colors.orange.shade100),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isActive 
                                                ? 'Active' 
                                                : (isFinalized ? 'Finalized' : 'Ended'),
                                            style: TextStyle(
                                              color: isActive 
                                                  ? Colors.green.shade800 
                                                  : (isFinalized ? Colors.blue.shade800 : Colors.orange.shade800),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            if (isActive && !hasEnded)
                                              ElevatedButton(
                                                onPressed: () => _showBidDialog(context, web3Service, deviceId, auction),
                                                child: const Text('Place Bid'),
                                              ),
                                            if (hasEnded && !isFinalized)
                                              ElevatedButton(
                                                onPressed: () => _finalizeAuction(web3Service, deviceId),
                                                child: const Text('Finalize Auction'),
                                              ),
                                            if (hasControl)
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DeviceControlScreen(
                                                        deviceId: deviceId,
                                                        endTime: endTime,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Control Device'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            return const Center(child: CircularProgressIndicator());
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Build an auction card for the given auction
  Widget _buildAuctionCard(Auction auction, Web3Service web3Service) {
    final now = DateTime.now();
    final hasEnded = auction.endTime.isBefore(now);
    final formattedTimeRemaining = auction.formattedTimeRemaining;
    final isActive = auction.isActive;
    final isFinalized = auction.isFinalized;
    final hasControl = auction.highestBidder == web3Service.currentAddress;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Device ID: ${auction.deviceId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0,
                    ),
                  ),
                ),
                if (hasControl)
                  const Chip(
                    label: Text('You have control'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text('Owner: ${_formatAddress(auction.owner)}'),
            const SizedBox(height: 4.0),
            Text('Start Time: ${_formatDateTime(auction.startTime)}'),
            Text('End Time: ${_formatDateTime(auction.endTime)}'),
            const SizedBox(height: 4.0),
            Text('Minimum Bid: ${auction.minimumBid} ETH'),
            Text('Highest Bid: ${auction.highestBid} ETH'),
            if (auction.highestBidder.isNotEmpty && auction.highestBidder != '0x0000000000000000000000000000000000000000')
              Text('Highest Bidder: ${_formatAddress(auction.highestBidder)}'),
            const SizedBox(height: 8.0),
            if (!hasEnded)
              Text(
                'Time Remaining: $formattedTimeRemaining',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            else if (!isFinalized)
              const Text(
                'Auction Ended (Not Finalized)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              )
            else
              const Text(
                'Auction Finalized',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive && !hasEnded)
                  ElevatedButton(
                    onPressed: () => _showBidDialog(context, web3Service, auction.deviceId, null),
                    child: const Text('Place Bid'),
                  ),
                if (hasEnded && !isFinalized)
                  ElevatedButton(
                    onPressed: () => _finalizeAuction(web3Service, auction.deviceId),
                    child: const Text('Finalize Auction'),
                  ),
                if (hasControl)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviceControlScreen(
                              deviceId: auction.deviceId,
                              endTime: auction.endTime,
                            ),
                          ),
                        );
                      },
                      child: const Text('Control Device'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final web3 = Provider.of<Web3Service>(context, listen: false);
      await web3.connect();
      
      // Give it a moment to connect before trying to initialize
      await Future.delayed(const Duration(seconds: 1));
      
      // Manually initialize contract and load auctions
      try {
        await web3.initializeContract();
        await web3.loadActiveAuctions();
      } catch (e) {
        developer.log('Contract initialization error: $e');
        // Continue anyway - we're at least connected
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showBidDialog(
    BuildContext context,
    Web3Service web3,
    String deviceId,
    Map<String, dynamic>? auction,
  ) async {
    final highestBid = auction?['highestBid'] is BigInt ? auction!['highestBid'] as BigInt : BigInt.zero;
    final minRequired = highestBid > BigInt.zero 
        ? highestBid + BigInt.one // Minimum increment of 1 wei
        : auction?['minBid'] is BigInt ? auction!['minBid'] as BigInt : BigInt.zero;
    
    // Convert wei to ETH for display
    final minRequiredEth = minRequired.toDouble() / 1e18;
    
    // Store context in a local variable to avoid using it across async gaps
    final currentContext = context;
    
    final amount = await _showBidDialogNew(currentContext, minRequiredEth);
    
    if (amount == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Store context in a local variable to avoid using it across async gaps
      final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
      final metaTxProvider = Provider.of<MetaTransactionProvider>(currentContext, listen: false);
      
      // Place bid using meta-transaction
      // ignore: unused_local_variable
      final txId = await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'placeBid(string,uint256)',
        functionParams: [deviceId, (amount * 1e18).toInt()],
        description: 'Bid $amount ETH on auction $deviceId',
      );
      
      // Show a subtle confirmation that the bid was submitted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Bid submitted'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      
      // Update pending transactions
      _updatePendingTransactions();
      
      // Refresh auctions after a short delay to allow transaction to process
      Future.delayed(const Duration(seconds: 2), _refreshAuctions);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to place bid: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeAuction(Web3Service web3, String deviceId) async {
    // Store context in a local variable to avoid using it across async gaps
    final currentContext = context;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Store context in a local variable to avoid using it across async gaps
      final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
      final metaTxProvider = Provider.of<MetaTransactionProvider>(currentContext, listen: false);
      
      // Finalize auction using meta-transaction
      // ignore: unused_local_variable
      final txId = await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'finalizeAuction(string)',
        functionParams: [deviceId],
        description: 'Finalize auction $deviceId',
      );
      
      // Show a subtle confirmation
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Finalization request submitted'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      
      // Update pending transactions
      _updatePendingTransactions();
      
      // Refresh auctions after a short delay to allow transaction to process
      Future.delayed(const Duration(seconds: 2), _refreshAuctions);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to finalize auction: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Format an Ethereum address for display
  String _formatAddress(String address) {
    if (address.isEmpty) {
      return 'N/A';
    }
    if (address.length < 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Format a DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatEther(BigInt wei) {
    final ethValue = wei.toDouble() / 1e18;
    return ethValue.toStringAsFixed(4);
  }

  void _showNetworkStatus() async {
    final web3Service = context.read<Web3Service>();
    final currentContext = context;
    
    // Show loading dialog
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Checking Network Status'),
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    
    try {
      // Get network status
      final status = await web3Service.checkNetworkStatus();
      
      // Close loading dialog
      if (mounted) Navigator.pop(currentContext);
      
      // Format the status information for display
      final formattedStatus = StringBuffer();
      formattedStatus.writeln('📊 Blockchain Status Report:');
      formattedStatus.writeln('');
      
      // Connection status
      final bool connected = status['connected'] ?? false;
      final bool mockMode = status['mockMode'] ?? false;
      
      if (mockMode) {
        formattedStatus.writeln('🔶 Running in MOCK MODE (no blockchain)');
        formattedStatus.writeln('');
      } else if (connected) {
        formattedStatus.writeln('✅ Connected to blockchain');
      } else {
        formattedStatus.writeln('❌ Not connected to blockchain');
        if (status['error'] != null) {
          formattedStatus.writeln('Error: ${status['error']}');
        }
        formattedStatus.writeln('');
      }
      
      // Network information
      if (status['networkName'] != null) {
        formattedStatus.writeln('🌐 Network: ${status['networkName']} (Chain ID: ${status['chainId']})');
      }
      
      // Account information
      if (status['account'] != null) {
        final account = status['account'] as String;
        final shortAccount = '${account.substring(0, 6)}...${account.substring(account.length - 4)}';
        formattedStatus.writeln('👤 Account: $shortAccount');
      }
      
      // Contract information
      if (status['contractAddress'] != null) {
        final contractAddress = status['contractAddress'] as String;
        final shortContract = '${contractAddress.substring(0, 6)}...${contractAddress.substring(contractAddress.length - 4)}';
        formattedStatus.writeln('📝 Contract: $shortContract');
        
        if (status['contractResponsive'] == true) {
          formattedStatus.writeln('✅ Contract is responsive');
          formattedStatus.writeln('📊 Auction Count: ${status['auctionCount']}');
        } else {
          formattedStatus.writeln('❌ Contract is not responsive');
          if (status['contractError'] != null) {
            formattedStatus.writeln('Error: ${status['contractError']}');
          }
        }
      }
      
      // Gas price
      if (status['gasPrice'] != null) {
        formattedStatus.writeln('⛽ Gas Price: ${status['gasPrice']} wei');
      }
      
      // Block number
      if (status['blockNumber'] != null) {
        formattedStatus.writeln('🧱 Block Number: ${status['blockNumber']}');
      }
      
      // Show the status dialog
      if (mounted) {
        showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('Network Status'),
            content: SingleChildScrollView(
              child: Text(formattedStatus.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  web3Service.toggleMockMode();
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          web3Service.isMockMode
                              ? 'Switched to mock mode'
                              : 'Switched to blockchain mode',
                        ),
                        backgroundColor: web3Service.isMockMode ? Colors.orange : Colors.blue,
                      ),
                    );
                  }
                  _refreshAuctions();
                },
                child: Text(
                  web3Service.isMockMode
                      ? 'Try Real Blockchain'
                      : 'Switch to Mock Mode',
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await web3Service.forceEnableMockMode();
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Forced mock mode with auctions'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  _refreshAuctions();
                },
                child: const Text(
                  'Force Mock Mode with Auctions',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(currentContext);
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to check network status: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _refreshAuctions() async {
    final web3Service = context.read<Web3Service>();
    await web3Service.loadActiveAuctions();
    
    // If a specific deviceId is provided, scroll to it after refreshing
    if (widget.deviceId != null) {
      _scrollToHighlightedAuction();
    }
  }

  Future<double?> _showBidDialogNew(BuildContext context, [double minBid = 0.1]) async {
    double? bidAmount;
    
    return showDialog<double?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Place a Bid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter bid amount in ETH (minimum ${minBid + 0.01} ETH):'),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g., ${(minBid + 0.01).toStringAsFixed(2)}',
                ),
                onChanged: (value) {
                  try {
                    bidAmount = double.parse(value);
                  } catch (_) {
                    bidAmount = null;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (bidAmount != null && bidAmount! > minBid) {
                  Navigator.pop(context, bidAmount);
                } else {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid amount greater than $minBid ETH'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void handleAuctionCreationError(dynamic e) {
    setState(() {
      _isLoading = false;
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      if (errorMsg.contains('insufficient funds')) {
        errorMsg = 'Insufficient funds in your wallet to create this auction';
      } else if (errorMsg.contains('user rejected')) {
        errorMsg = 'Transaction was rejected in your wallet';
      } else if (errorMsg.contains('Internal JSON-RPC error')) {
        errorMsg = 'Blockchain connection error. Switched to mock mode.';
      } else if (errorMsg.contains('execution reverted')) {
        final revertMatch = RegExp(r'reverted: (.+?)(?:,|$)').firstMatch(errorMsg);
        if (revertMatch != null) {
          errorMsg = 'Smart contract error: ${revertMatch.group(1)}';
        } else {
          errorMsg = 'Smart contract rejected the transaction';
        }
      }
      _errorMessage = errorMsg;
    });

    // Store context in a local variable to avoid using it across async gaps
    final currentContext = context;
    if (mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Error: $_errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              // Use the stored context here
              showDialog(
                context: currentContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Error Details'),
                  content: SingleChildScrollView(
                    child: Text(e.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _updateEndDate() {
    setState(() {
      _endDate = _startDate.add(Duration(hours: int.parse(_totalTimePeriodController.text)));
      _endDateController.text = _formatDateTime(_endDate);
    });
  }
}
