import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction.dart';
import '../providers/mock_auction_provider.dart';
import '../providers/meta_transaction_provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import '../widgets/wavy_background.dart';

class AuctionScreen extends StatefulWidget {
  final int initialTab;
  final String? deviceId;
  final bool showOnlySpecificDevice;
  final List<MapEntry<String, Map<String, dynamic>>>? preFilteredSessions;

  const AuctionScreen({
    super.key,
    this.initialTab = 0,
    this.deviceId,
    this.showOnlySpecificDevice = false,
    this.preFilteredSessions,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  List<Auction> _auctions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingMessage = 'Loading...';
  final _auctionsScrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  // Auction creation form fields
  TextEditingController _deviceIdController = TextEditingController();
  TextEditingController _startTimeController = TextEditingController();
  TextEditingController _durationController = TextEditingController();
  TextEditingController _minimumBidController = TextEditingController();
  TextEditingController _numSlotsController = TextEditingController();
  TextEditingController _slotDurationController = TextEditingController();

  DateTime _selectedStartTime = DateTime.now().add(const Duration(minutes: 5));
  List<Map<String, dynamic>> _pendingTransactions = [];
  final Set<String> _shownCompletionNotifications = {};

  // Initialize controllers and fetch auctions
  @override
  void initState() {
    super.initState();
    _log('AuctionScreen initState');

    // Check if we're in mock mode and force create auctions if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndCreateMockAuctions();
    });

    _deviceIdController.text = 'device-${DateTime.now().millisecondsSinceEpoch}';
    _startTimeController.text = _formatDateTime(_selectedStartTime);
    _durationController.text = '60';
    _minimumBidController.text = '0.01';
    _numSlotsController.text = '6';
    _slotDurationController.text = '5';

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
          .where((tx) => tx.status == MetaTransactionStatus.submitted || tx.status == MetaTransactionStatus.processing)
          .map((tx) => {'id': tx.id, 'status': tx.status})
          .toList();
    });

    // If there are any newly confirmed or failed transactions, show a brief toast
    final recentlyCompleted = metaTxProvider.transactions
        .where((tx) => (tx.status == MetaTransactionStatus.confirmed || tx.status == MetaTransactionStatus.failed) &&
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
            backgroundColor: tx.status == MetaTransactionStatus.confirmed ? Colors.green : Colors.red,
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
  void _checkAndCreateMockAuctions() {
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
            _refreshData();
          }
        } else {
          _log('Mock auctions already exist: ${result.data?.length ?? 0}');
        }
      }
    });
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _startTimeController.dispose();
    _durationController.dispose();
    _minimumBidController.dispose();
    _numSlotsController.dispose();
    _slotDurationController.dispose();
    _auctionsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web3 = Provider.of<Web3Service>(context);
    final buttplug = Provider.of<MockButtplugService>(context);
    final metaTxProvider = Provider.of<MetaTransactionProvider>(context);

    // Update pending transactions when provider changes
    if (_pendingTransactions.length != metaTxProvider.transactions
        .where((tx) => tx.status == MetaTransactionStatus.submitted || tx.status == MetaTransactionStatus.processing)
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
              message: web3.isMockMode
                  ? 'Running in mock mode (no blockchain)'
                  : web3.isConnected
                      ? 'Connected to blockchain'
                      : 'Not connected to blockchain',
              child: IconButton(
                icon: Icon(
                  web3.isMockMode
                      ? Icons.cloud_off
                      : web3.isConnected
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                  color: web3.isMockMode
                      ? Colors.orange
                      : web3.isConnected
                          ? Colors.green
                          : Colors.red,
                ),
                onPressed: _showNetworkStatus,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
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
        body: Stack(
          children: [
            // Background with gradient waves
            const WavyBackground(
              primaryColor: Colors.blue,
              secondaryColor: Colors.purple,
              child: SizedBox.expand(),
            ),

            // Main content
            TabBarView(
              children: [
                _buildCreateAuctionTab(web3, buttplug),
                _buildActiveAuctionsTab(),
              ],
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
              controller: _startTimeController,
              decoration: const InputDecoration(
                labelText: 'Start Time',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a start time';
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
                  _selectedStartTime = DateTime.parse(value);
                } catch (e) {
                  // Invalid date format, ignore
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter duration';
                }
                final minutes = int.tryParse(value);
                if (minutes == null || minutes <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Minimum Bid (ETH)',
                border: OutlineInputBorder(),
              ),
              controller: _minimumBidController,
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

                          final deviceId = _deviceIdController.text;
                          if (deviceId.isEmpty) {
                            // Use a mock device ID if no device is selected
                            final mockDeviceId = 'mock_device_${DateTime.now().millisecondsSinceEpoch}';
                            _log('No device selected, using mock device ID: $mockDeviceId');

                            // Convert form values to appropriate types
                            final minBidEth = double.parse(_minimumBidController.text);
                            final duration = int.parse(_durationController.text);

                            _log('Creating auction with params:');
                            _log('Device ID: $mockDeviceId');
                            _log('Start Time: $_selectedStartTime');
                            _log('Duration: $duration minutes');
                            _log('Min Bid: $minBidEth ETH');

                            // Call the contract method with mock device ID
                            try {
                              if (kIsWeb) {
                                // Use MockAuctionProvider for web
                                final mockAuctionProvider = context.read<MockAuctionProvider?>();
                                if (mockAuctionProvider != null) {
                                  _log('Using MockAuctionProvider for web to create auction');
                                  final success = await mockAuctionProvider.createAuction(
                                    deviceId: mockDeviceId,
                                    startTime: _selectedStartTime,
                                    duration: Duration(minutes: duration),
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
                                    startTime: _selectedStartTime,
                                    duration: Duration(minutes: duration),
                                    minimumBid: minBidEth,
                                  );
                                }
                              } else {
                                // Use Web3Service for non-web platforms
                                await web3.createAuction(
                                  deviceId: mockDeviceId,
                                  startTime: _selectedStartTime,
                                  duration: Duration(minutes: duration),
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
                            final minBidEth = double.parse(_minimumBidController.text);
                            final duration = int.parse(_durationController.text);

                            _log('Creating auction with params:');
                            _log('Device ID: $deviceId');
                            _log('Start Time: $_selectedStartTime');
                            _log('Duration: $duration minutes');
                            _log('Min Bid: $minBidEth ETH');

                            // Call the contract method
                            try {
                              if (kIsWeb) {
                                // Use MockAuctionProvider for web
                                final mockAuctionProvider = context.read<MockAuctionProvider?>();
                                if (mockAuctionProvider != null) {
                                  _log('Using MockAuctionProvider for web to create auction with real device');
                                  final success = await mockAuctionProvider.createAuction(
                                    deviceId: deviceId,
                                    startTime: _selectedStartTime,
                                    duration: Duration(minutes: duration),
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
                                    startTime: _selectedStartTime,
                                    duration: Duration(minutes: duration),
                                    minimumBid: minBidEth,
                                  );
                                }
                              } else {
                                // Use Web3Service for non-web platforms
                                await web3.createAuction(
                                  deviceId: deviceId,
                                  startTime: _selectedStartTime,
                                  duration: Duration(minutes: duration),
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

    // If we should only show a specific device and have pre-filtered sessions
    if (widget.showOnlySpecificDevice && widget.preFilteredSessions != null) {
      _log('Showing only pre-filtered sessions for device: ${widget.deviceId}');

      for (var entry in widget.preFilteredSessions!) {
        _log('Pre-filtered session: ${entry.key}');
      }

      if (widget.preFilteredSessions!.isEmpty) {
        return const Center(
          child: Text('No auction sessions found for this device'),
        );
      }
      
      // Convert the MapEntry list to Auction objects
      final List<Auction> auctionSessions = widget.preFilteredSessions!.map((entry) {
        _log('Converting session: ${entry.key}');

        // If it's already an Auction, use it directly
        if (entry.value is Auction) {
          _log('Entry is already an Auction object');
          return entry.value as Auction;
        }

        // Otherwise, create an Auction from the Map
        _log('Creating Auction from Map for device: ${entry.key}');

        try {
          final data = Map<String, dynamic>.from(entry.value);
          data['deviceId'] = entry.key; // Ensure deviceId is set from the map entry key
          return Auction.fromBlockchainData(data);
        } catch (e) {
          _log('Error converting session to Auction: $e');
          return Auction(
            deviceId: entry.key,
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            owner: 'unknown',
            minimumBid: 0.01,
            isActive: true,
            isFinalized: false,
          );
        }
      }).toList();

      _log('Converted ${auctionSessions.length} auction sessions');

      // Check if we have any sessions
      if (auctionSessions.isEmpty) {
        return const Center(
          child: Text('No auction sessions available'),
        );
      }

      // Group the sessions by base device ID
      final groupedSessions = _groupAuctionsByBaseDevice(auctionSessions);
      _log('Grouped sessions by base device ID: ${groupedSessions.keys.join(', ')}');

      // Try to find the exact device ID first
      if (widget.deviceId != null && groupedSessions.containsKey(widget.deviceId)) {
        _log('Found exact match for device ID: ${widget.deviceId}');
        final slots = groupedSessions[widget.deviceId]!;

        return SingleChildScrollView(
          child: Column(
            children: [
              Text('Found ${slots.length} auction slots for device ${widget.deviceId}'),
              _buildDeviceWithMultiSlotsCard(widget.deviceId!, slots, web3Service),
            ],
          ),
        );
      }

      // Look for sessions that might start with the base device ID
      final String? baseDeviceId = widget.deviceId?.split('-session-').first;
      _log('Looking for base device ID: $baseDeviceId');

      if (baseDeviceId != null) {
        // Find any key that matches the base device ID pattern
        final matchingKey = groupedSessions.keys.firstWhere(
          (key) => key.startsWith(baseDeviceId) || key.contains(baseDeviceId),
          orElse: () => '',
        );

        if (matchingKey.isNotEmpty) {
          _log('Found matching key for base device ID: $matchingKey');
          final slots = groupedSessions[matchingKey]!;

          return SingleChildScrollView(
            child: Column(
              children: [
                Text('Found ${slots.length} auction slots for device $matchingKey'),
                _buildDeviceWithMultiSlotsCard(matchingKey, slots, web3Service),
              ],
            ),
          );
        }
      }

      // If we have any auctions at all, just show the first group
      if (groupedSessions.isNotEmpty) {
        _log('No exact match found, showing first group of sessions');
        final firstDeviceId = groupedSessions.keys.first;
        final slots = groupedSessions[firstDeviceId]!;

        return SingleChildScrollView(
          child: Column(
            children: [
              Text('Showing ${slots.length} auction slots for device $firstDeviceId'),
              _buildDeviceWithMultiSlotsCard(firstDeviceId, slots, web3Service),
            ],
          ),
        );
      }

      // Fallback if no sessions are found
      return Center(
        child: Text('No sessions found for device: ${widget.deviceId}'),
      );
    }
    
    // In web mode, use the MockAuctionProvider if available
    if (kIsWeb) {
      final mockAuctionProvider = context.watch<MockAuctionProvider?>();
      if (mockAuctionProvider != null) {
        _log('Using MockAuctionProvider for web');
        final mockAuctions = mockAuctionProvider.auctions;
        _log('Found ${mockAuctions.length} mock auctions');

        if (mockAuctions.isEmpty) {
          return const Center(
            child: Text('No active auctions available'),
          );
        }

        // Group auctions by their base device ID
        final groupedAuctions = _groupAuctionsByBaseDevice(mockAuctions);
        _log('Grouped ${groupedAuctions.length} device auctions from ${mockAuctions.length} auctions');

        return _buildGroupedAuctionsList(groupedAuctions, web3Service);
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Pending transactions section
          if (_pendingTransactions.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pending_actions, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Pending Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_pendingTransactions.isEmpty)
                      const Text('No pending transactions')
                    else
                      ExpansionTile(
                        title: Text('${_pendingTransactions.length} transactions in progress'),
                        children: [
                          ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'These transactions are being processed on the blockchain and may take a few minutes to complete.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._pendingTransactions.map((tx) {
                                // Convert the map to a format TransactionStatusWidget can use
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Card(
                                    elevation: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Transaction ID: ${tx['id']}'),
                                          Text('Status: ${tx['status']}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          
          // Auctions list
          Expanded(
            child: FutureBuilder<List<Auction>>(
              future: _fetchAuctions(web3Service),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                } else {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // Process auction entries to handle both Map and Auction objects
                    final auctionList = _processAuctionEntries(web3Service.activeAuctions);

                    // Group auctions by base device ID
                    final groupedAuctions = _groupAuctionsByBaseDevice(auctionList);

                    if (groupedAuctions.isEmpty) {
                      return const Center(
                        child: Text('No active auctions found'),
                      );
                    }

                    return ListView.builder(
                      controller: _auctionsScrollController,
                      itemCount: groupedAuctions.length,
                      itemBuilder: (context, index) {
                        final deviceId = groupedAuctions.keys.elementAt(index);
                        final slots = groupedAuctions[deviceId]!;

                        // Highlight the card if it matches the deviceId parameter
                        final isHighlighted = widget.deviceId != null && deviceId == widget.deviceId;

                        // Apply highlighting if needed
                        if (isHighlighted) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.all(8),
                            child: _buildDeviceWithMultiSlotsCard(deviceId, slots, web3Service),
                          );
                        }

                        return _buildDeviceWithMultiSlotsCard(deviceId, slots, web3Service);
                      },
                    );
                  }
                  return const Center(child: Text('No data available'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Auction>> _fetchAuctions(Web3Service web3Service) async {
    // Set auctions in state
    _auctions = _processAuctionEntries(web3Service.activeAuctions);
    return _auctions;
  }

  /// Process and display auction entries, handling both auction objects and maps
  List<Auction> _processAuctionEntries(Map<String, dynamic> auctions) {
    final List<Auction> result = [];

    for (final entry in auctions.entries) {
      if (entry.value is Auction) {
        // If it's already an Auction object, add it directly
        result.add(entry.value as Auction);
        // Important: return here to prevent reaching the conversion code below
        continue;
      }

      // Handle Map representation
      if (entry.value is Map<String, dynamic>) {
        try {
          final auctionData = entry.value as Map<String, dynamic>;
          final auction = Auction.fromBlockchainData(auctionData);
          result.add(auction);
        } catch (e) {
          _log('Failed to convert auction data to Auction object: $e');
        }
      }
    }

    return result;
  }

  /// Group auctions by their base device ID
  Map<String, List<Auction>> _groupAuctionsByBaseDevice(List<Auction> auctions) {
    final Map<String, List<Auction>> result = {};

    for (final auction in auctions) {
      // Extract the base device ID
      String baseDeviceId = auction.deviceId;

      // Check for both formats: deviceId-session-X and deviceId::timestamp
      if (baseDeviceId.contains('-session-')) {
        baseDeviceId = baseDeviceId.split('-session-').first;
      } else if (baseDeviceId.contains('::')) {
        baseDeviceId = baseDeviceId.split('::').first;
      }

      _log('Grouping auction: ${auction.deviceId} with base ID: $baseDeviceId');

      // Add to group
      if (!result.containsKey(baseDeviceId)) {
        result[baseDeviceId] = [];
      }

      result[baseDeviceId]!.add(auction);
    }

    // Sort each group by start time
    result.forEach((key, slots) {
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    return result;
  }

  /// Build a card for displaying a device with multiple auction slots
  Widget _buildDeviceWithMultiSlotsCard(String deviceId, List<Auction> slots, Web3Service web3Service) {
    // Sort slots by start time
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.devices,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device ID: ${_formatAddress(deviceId)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Owner: ${_formatAddress(slots.first.owner)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${slots.length} time slots available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Slot List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slot = slots[index];
                final now = DateTime.now();
                final isActive = slot.startTime.isBefore(now) && slot.endTime.isAfter(now);
                final hasEnded = slot.endTime.isBefore(now);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isActive
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withOpacity(0.3),
                      width: isActive ? 1 : 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Time indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : (hasEnded
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.secondary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isActive
                                ? 'ACTIVE'
                                : (hasEnded ? 'ENDED' : 'UPCOMING'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Slot details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Slot ${index + 1}: ${_formatDateTime(slot.startTime)} - ${_formatDateTime(slot.endTime)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Min Bid: ${_formatEther(slot.minimumBid)} ETH',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (slot.highestBid > 0)
                                          Text(
                                            'Current Bid: ${_formatEther(slot.highestBid)} ETH',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        if (slot.highestBidder.isNotEmpty && slot.highestBidder != '0x0000000000000000000000000000000000000000')
                                          Text(
                                            'By: ${_formatAddress(slot.highestBidder)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Actions
                                  if (!slot.isFinalized && !hasEnded)
                                    ElevatedButton(
                                      onPressed: () => _bidOnAuction(slot),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      child: const Text('Bid'),
                                    )
                                  else if (!slot.isFinalized && hasEnded && slot.highestBidder == web3Service.currentAddress)
                                    ElevatedButton(
                                      onPressed: () => _finalizeAuctionSlot(slot.deviceId),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      child: const Text('Finalize'),
                                    )
                                  else if (slot.isFinalized)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'FINALIZED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build a ListView of grouped auction slots
  Widget _buildGroupedAuctionsList(Map<String, List<Auction>> groupedAuctions, Web3Service web3Service) {
    // Sort groups so they appear in a consistent order
    final sortedKeys = groupedAuctions.keys.toList()..sort();

    return ListView.builder(
      controller: _auctionsScrollController,
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final deviceId = sortedKeys[index];
        final slots = groupedAuctions[deviceId]!;

        // Sort slots by start time
        slots.sort((a, b) => a.startTime.compareTo(b.startTime));

        return _buildDeviceWithMultiSlotsCard(deviceId, slots, web3Service);
      },
    );
  }

  /// Method to refresh auction data
  Future<void> _refreshData() async {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
    
    _showLoadingIndicator('Refreshing auctions...');
    _errorMessage = null;
    
    try {
      await web3Service.loadActiveAuctions();
      
      // If a specific deviceId is provided, scroll to it after refreshing
      if (widget.deviceId != null) {
        _scrollToHighlightedAuction();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to refresh auctions: ${e.toString()}';
      });
      _log('Error refreshing auctions: ${e.toString()}');
    } finally {
      _hideLoadingIndicator();
    }
  }

  /// Method to show network status dialog
  void _showNetworkStatus() async {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
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
                  _refreshData();
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
                  _refreshData();
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

  /// Log a message with the AuctionScreen prefix
  void _log(String message) {
    developer.log('AuctionScreen: $message');
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

  /// Format a value to ETH, handling both BigInt (wei) and double (already in ETH) values
  String _formatEther(dynamic value) {
    if (value is BigInt) {
      // Convert from wei to ETH
      final ethValue = value.toDouble() / 1e18;
      return ethValue.toStringAsFixed(4);
    } else if (value is double) {
      // Already in ETH
      return value.toStringAsFixed(4);
    } else if (value is num) {
      // Other numeric type
      return (value.toDouble()).toStringAsFixed(4);
    } else {
      // Unknown type
      return '0.0000';
    }
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

  void _bidOnAuction(Auction auction) {
    _showBidDialog(
      context,
      auction,
      Provider.of<Web3Service>(context, listen: false),
      _refreshData,
    );
  }

  void _finalizeAuctionSlot(String auctionId) {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
    _finalizeAuction(web3Service, auctionId);
  }

  Future<void> _showBidDialog(
    BuildContext context,
    Auction auction,
    Web3Service web3,
    VoidCallback refreshData,
  ) async {
    final highestBid = auction.highestBid;
    final minRequired = highestBid > 0
        ? highestBid + 0.000000000000000001 // Minimum increment of 1 wei
        : auction.minimumBid;

    // Convert wei to ETH for display
    final minRequiredEth = minRequired;

    double amount = minRequiredEth;

    final controller = TextEditingController(text: minRequiredEth.toString());

    // Show the bid dialog
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place a Bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Minimum bid: $minRequiredEth ETH'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Bid Amount (ETH)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                try {
                  amount = double.parse(value);
                } catch (e) {
                  // Invalid input, keep the last valid amount
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(amount),
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );

    if (result == null) return; // User cancelled

    // Place the bid using the Web3Service
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Placing bid...';
    });

    try {
      final metaTxProvider = Provider.of<MetaTransactionProvider>(context, listen: false);

      // Create the transaction
      final txId = await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'placeBid(string,uint256)',
        functionParams: [auction.deviceId, (result * 1e18).toInt()],
        description: 'Bid $result ETH on auction ${auction.deviceId}',
      );

      // Show a subtle confirmation that the bid was submitted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bid submitted! Transaction ID: ${txId.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Maybe open a transaction details page
            },
          ),
        ),
      );

      _updatePendingTransactions();

      // Refresh auctions after a short delay to allow transaction to process
      Future.delayed(const Duration(seconds: 2), refreshData);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to place bid: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place bid: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeAuction(Web3Service web3, String deviceId) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Finalizing auction...';
    });

    try {
      final metaTxProvider = Provider.of<MetaTransactionProvider>(context, listen: false);

      // Create the transaction
      final txId = await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'finalizeAuction(string)',
        functionParams: [deviceId],
        description: 'Finalize auction for device $deviceId',
      );

      // Show a subtle confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finalization submitted! Transaction ID: ${txId.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Maybe open a transaction details page
            },
          ),
        ),
      );

      _updatePendingTransactions();

      // Refresh auctions after a delay
      Future.delayed(const Duration(seconds: 2), _refreshData);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to finalize auction: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to finalize auction: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLoadingIndicator(String message) {
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
  }

  void _hideLoadingIndicator() {
    setState(() {
      _isLoading = false;
    });
  }
}
