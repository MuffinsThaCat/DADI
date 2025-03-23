import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction.dart';
import '../providers/meta_transaction_provider.dart';
import '../services/navigation_service.dart';
import '../services/web3_service.dart';
import '../services/multi_slot_auction_service.dart';
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

class _AuctionScreenState extends State<AuctionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Auction> _auctions = [];
  bool _isRefreshing = false;
  bool _isLoading = false;
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _minimumBidController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<int> _slotDurations = [15, 30, 45, 60, 90, 120, 240]; // In minutes
  int _selectedSlotDuration = 60; // Default: 1 hour
  final List<Map<String, dynamic>> _pendingTransactions = [];
  bool _isWarningVisible = true; // Controls blinking effect for auction warnings
  Timer? _warningBlinkTimer;

  // Initialize controllers and fetch auctions
  @override
  void initState() {
    super.initState();
    _log('AuctionScreen - initState');
    
    // Set default value
    _minimumBidController.text = '0.01';
    _deviceIdController.text = 'device-${DateTime.now().millisecondsSinceEpoch}';

    // Create TabController
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.deviceId != null ? 1 : widget.initialTab,
    );

    // Add listener to TabController
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.animation!.value % 1 == 0) {
        // Check which tab is selected
        final selectedTab = _tabController.index;

        // If active auctions tab is selected, refresh data
        if (selectedTab == 1) {
          _log('Switched to Active Auctions tab, refreshing data');

          // Refresh data when switching to the active auctions tab
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _refreshData(forceRefresh: true);
            }
          });
        }
      }
    });

    // Initialize with an immediately resolving empty list to avoid infinite loading
    _cachedAuctionsFuture = Future.value([]);
    
    // Set up timer to refresh auction data
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });

    // Update any pending transactions
    _updatePendingTransactions();

    // Setup blinking timer for warnings
    _warningBlinkTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        setState(() {
          _isWarningVisible = !_isWarningVisible; // Toggle visibility for blinking effect
        });
      }
    });

    // Schedule initialization after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _log('AuctionScreen - post frame callback');
      _checkAndCreateMockAuctions();
      
      // Refresh data to load actual auctions
      _refreshData(forceRefresh: true);
    });
  }

  Future<List<Auction>>? _cachedAuctionsFuture;

  // Refresh auctions and update the cached future
  Future<void> _refreshAuctions() async {
    setState(() {
      _cachedAuctionsFuture = _fetchAuctions();
    });
  }

  void _updatePendingTransactions() {
    try {
      final metaTxProvider = Provider.of<MetaTransactionProvider>(
        NavigationService.navigatorKey.currentContext!,
        listen: false,
      );

      // Collect all pending transactions
      List<Map<String, dynamic>> pendingTx = [];

      for (var tx in metaTxProvider.transactions) {
        if (tx.status == MetaTransactionStatus.submitted ||
            tx.status == MetaTransactionStatus.processing) {
          pendingTx.add({
            'id': tx.id,
            'description': tx.description,
            'timestamp': tx.timestamp,
          });
        }
      }

      // Replace the list contents
      _pendingTransactions.clear();
      _pendingTransactions.addAll(pendingTx);

      // Check for completed transactions to notify users
      for (var tx in metaTxProvider.transactions) {
        if (tx.status == MetaTransactionStatus.confirmed &&
            !_pendingTransactions.any((t) => t['id'] == tx.id)) {
          // Show notification for this completed transaction
          _showTransactionCompleteNotification(tx.id, tx.description);
        }
      }
    } catch (e) {
      _log('Error updating transaction status: $e');
    }
  }

  /// Show notification for completed transaction
  void _showTransactionCompleteNotification(String id, String description) {
    try {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction completed: $description'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      _log('Error showing notification: $e');
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _minimumBidController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _warningBlinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web3 = context.watch<Web3Service>();

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
              controller: _tabController,
              children: [
                _buildCreateAuctionTab(),
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
                      const Text(
                        'Loading...',
                        style: TextStyle(
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

  Widget _buildCreateAuctionTab() {
    return Stack(
      children: [
        if (kIsWeb)
          // Background only on web to avoid mobile performance issues
          const WavyBackground(
            primaryColor: Color(0xFF6200EE),
            secondaryColor: Color(0xFF03DAC6),
            child: SizedBox.expand(),
          ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create New Auction',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Device ID field
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'Enter device ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a device ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Minimum bid field
              TextFormField(
                controller: _minimumBidController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bid (ETH)',
                  hintText: 'Enter minimum bid amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a minimum bid';
                  }
                  try {
                    final bid = double.parse(value);
                    if (bid <= 0) {
                      return 'Minimum bid must be greater than 0';
                    }
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Slot duration dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Auction Duration',
                  border: OutlineInputBorder(),
                ),
                value: _selectedSlotDuration,
                items: _slotDurations.map((duration) {
                  // Calculate number of 5-minute slots for this duration
                  final numSlots = duration ~/ 5;
                  return DropdownMenuItem<int>(
                    value: duration,
                    child: Text('$duration minutes ($numSlots slots)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      _selectedSlotDuration = value;
                    }
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an auction duration';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Slot duration explanation
              const Text(
                'Each slot represents a 5-minute time period for bidding.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAuctionForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Auction'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveAuctionsTab() {
    _log('Building active auctions tab');
    
    return FutureBuilder<List<Auction>>(
      future: _cachedAuctionsFuture,
      builder: (context, snapshot) {
        _log('FutureBuilder state: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          _log('FutureBuilder is in waiting state');
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          _log('FutureBuilder has error: ${snapshot.error}');
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        // Check if we have data
        if (!snapshot.hasData) {
          _log('FutureBuilder has no data');
          return const Center(
            child: Text('No auction data available'),
          );
        }
        
        if (snapshot.data!.isEmpty) {
          _log('FutureBuilder has empty data');
          return const Center(
            child: Text('No active auctions found'),
          );
        }

        _log('FutureBuilder has data with ${snapshot.data!.length} auctions');
        // Build the list of auctions using the fetched data
        return _buildAuctionsList(snapshot.data!);
      },
    );
  }

  /// Helper method to build the list of auctions
  Widget _buildAuctionsList(List<Auction> auctions) {
    if (auctions.isEmpty) {
      return const Center(
        child: Text('No active auctions found'),
      );
    }

    // Group auctions by base device ID
    final groupedAuctions = _groupAuctionsByBaseDevice(auctions);

    // Build a list of cards for each group
    return ListView.builder(
      controller: _scrollController,
      itemCount: groupedAuctions.length,
      itemBuilder: (context, index) {
        final deviceId = groupedAuctions.keys.elementAt(index);
        final deviceAuctions = groupedAuctions[deviceId]!;

        return _buildDeviceAuctionCard(deviceId, deviceAuctions);
      },
    );
  }

  /// Process auction entries from various data sources
  List<Auction> _processAuctionEntries(List<dynamic> entries) {
    _log('Processing ${entries.length} auction entries');
    
    // If the list is empty, return empty
    if (entries.isEmpty) {
      return [];
    }
    
    // If we have only one item and it's already an Auction, just return it
    if (entries.length == 1 && entries[0] is Auction) {
      final auction = entries[0] as Auction;
      _log('Single Auction object found: ${auction.deviceId}');
      return [auction];
    }
    
    List<Auction> result = [];

    for (final dynamic auctionData in entries) {
      try {
        if (auctionData is Auction) {
          final auction = auctionData; 
          _log('Adding direct Auction object: ${auction.deviceId}');
          result.add(auction);
          continue; // Skip to next auction (don't try to process as Map)
        }

        _log('Processing non-Auction data of type: ${auctionData.runtimeType}');

        // Create an empty map and populate it from the data
        Map<String, dynamic> auctionMap = {};
        
        if (auctionData is Map) {
          auctionData.forEach((k, v) {
            auctionMap[k.toString()] = v;
          });
        } else {
          _log('Cannot convert to map, skipping');
          continue;
        }

        if (auctionMap.isEmpty) {
          _log('Empty map data, skipping');
          continue;
        }

        _log('Map keys: ${auctionMap.keys.join(', ')}');

        // Extract required fields with additional error handling
        try {
          final deviceId = auctionMap['deviceId'] ?? 'unknown-device';
          final owner = auctionMap['owner'] ?? 'unknown';
          final startTimeStr = auctionMap['startTime'];
          final endTimeStr = auctionMap['endTime'];

          // Support both naming conventions (with and without 'minimum' prefix)
          final minimumBidStr = auctionMap['minimumBid'] ?? auctionMap['minBid'];
          final highestBidStr = auctionMap['highestBid'];
          final highestBidder = auctionMap['highestBidder'] ?? '';

          // Support both naming conventions (with and without 'is' prefix)
          final isActive = auctionMap['isActive'] ?? auctionMap['active'] ?? true;
          final isFinalized = auctionMap['isFinalized'] ?? auctionMap['finalized'] ?? false;
          final isUserCreated = auctionMap['isUserCreated'] ?? false;

          // Parse timestamps and bids
          DateTime startTime = DateTime.now();
          DateTime endTime = DateTime.now().add(const Duration(hours: 1));

          // Parse timestamps
          if (startTimeStr != null) {
            if (startTimeStr is String) {
              startTime = DateTime.tryParse(startTimeStr) ?? startTime;
            } else if (startTimeStr is DateTime) {
              startTime = startTimeStr;
            }
          }

          if (endTimeStr != null) {
            if (endTimeStr is String) {
              endTime = DateTime.tryParse(endTimeStr) ?? endTime;
            } else if (endTimeStr is DateTime) {
              endTime = endTimeStr;
            } else if (endTimeStr is BigInt) {
              // Handle BigInt timestamp (seconds since epoch)
              endTime = DateTime.fromMillisecondsSinceEpoch(endTimeStr.toInt() * 1000);
            }
          }

          // Check for actual slot times in additionalData (used by multi-slot auctions)
          if (auctionMap['additionalData'] != null && 
              auctionMap['additionalData']['actualSlotStartTime'] != null && 
              auctionMap['additionalData']['actualSlotEndTime'] != null) {
            
            try {
              // Use the actual slot times for display
              startTime = DateTime.parse(auctionMap['additionalData']['actualSlotStartTime']);
              endTime = DateTime.parse(auctionMap['additionalData']['actualSlotEndTime']);
              _log('Using actual slot times from additionalData: $startTime - $endTime');
            } catch (e) {
              _log('Error parsing actual slot times: $e');
            }
          }

          // Parse bids
          double minimumBid = 0.0;
          double highestBid = 0.0;

          try {
            minimumBid = minimumBidStr != null
                ? (minimumBidStr is num
                    ? minimumBidStr.toDouble()
                    : double.tryParse(minimumBidStr.toString()) ?? 0.0)
                : 0.0;

            highestBid = highestBidStr != null
                ? (highestBidStr is num
                    ? highestBidStr.toDouble()
                    : double.tryParse(highestBidStr.toString()) ?? 0.0)
                : 0.0;
          } catch (e) {
            _log('Error parsing bids: $e');
          }

          // Create the auction object
          final auction = Auction(
            deviceId: deviceId,
            owner: owner,
            startTime: startTime,
            endTime: endTime,
            minimumBid: minimumBid,
            highestBid: highestBid,
            highestBidder: highestBidder,
            isActive: isActive,
            isFinalized: isFinalized,
            isUserCreated: isUserCreated,
            additionalData: auctionMap['additionalData'] ?? {},
          );

          _log('Created auction: ${auction.deviceId} (${auction.startTime} - ${auction.endTime})');
          result.add(auction);
        } catch (e, stack) {
          _log('Error processing auction map: $e\n$stack');
        }
      } catch (e, stack) {
        _log('Error processing auction entry: $e\n$stack');
      }
    }

    _log('Completed processing: returning ${result.length} auctions');
    return result;
  }

  /// Fetch auctions from Web3Service
  Future<List<Auction>> _fetchAuctions() async {
    _log('Fetching auctions from Web3Service');
    try {
      final web3Service = Provider.of<Web3Service>(context, listen: false);

      // For web mode, we now use Web3Service directly since MockAuctionProvider is removed
      if (kIsWeb) {
        _log('Running on web platform, using Web3Service directly');
      }

      // Force refresh to get the latest data
      _log('Refreshing auctions from Web3Service');
      await web3Service.refreshAuctions();

      _log('Web3Service has ${web3Service.activeAuctions.length} active auctions');
      if (web3Service.activeAuctions.isNotEmpty) {
        _log('Auction keys: ${web3Service.activeAuctions.keys.join(', ')}');
      }

      // Process auction entries
      final allAuctions = web3Service.activeAuctions;
      final userAddress = web3Service.currentAddress?.toLowerCase() ?? '';
      
      // Filter auctions to remove mock auctions that weren't created by this user
      final filteredAuctions = Map.fromEntries(
        allAuctions.entries.where((entry) {
          final key = entry.key;
          
          // Check if it's a mock device that wasn't created by this user
          final isMockDevice = key.toString().startsWith('mock-device-');
          
          // Get the owner address and check if it matches the current user
          String ownerAddress = '';
          bool isUserCreated = false;
          
          // Use a completely different approach to avoid type issues
          try {
            final dynamic auction = entry.value;
            
            // Handle both Auction objects and Map data structures
            if (auction is Auction) {
              ownerAddress = auction.owner.toLowerCase();
              isUserCreated = auction.isUserCreated;
            } else if (auction is Map) {
              // Access as Map entries
              auction.forEach((k, v) {
                if (k.toString() == 'owner' && v != null) {
                  ownerAddress = v.toString().toLowerCase();
                }
                if (k.toString() == 'isUserCreated' && v == true) {
                  isUserCreated = true;
                }
              });
            }
          } catch (e) {
            _log('Error extracting auction data: $e');
          }
          
          // Include the auction if:
          // 1. It's explicitly marked as user-created, OR
          // 2. The user owns it AND it's not a mock device
          return isUserCreated || (userAddress.isNotEmpty && ownerAddress == userAddress && !isMockDevice);
        })
      );
      
      _log('Filtered to ${filteredAuctions.length} auctions after removing unwanted mock auctions');

      // Convert the Map to a List for processing
      final List<dynamic> auctionsList = [];

      // Using a for loop instead of forEach for better control flow
      for (final entry in filteredAuctions.entries) {
        final key = entry.key;
        final value = entry.value;

        _log('Processing auction for key: $key, value type: ${value.runtimeType}');

        if (value is Auction) {
          _log('Direct Auction object found for: $key');
          auctionsList.add(value);
          continue; // Skip to next iteration to avoid type errors
        } else {
          // Handle all Map types
          try {
            Map<String, dynamic> mapCopy = {};
            
            // Check runtime type and convert appropriately
            value.forEach((k, v) {
              mapCopy[k.toString()] = v;
            });
            
            // Ensure deviceId is set
            if (!mapCopy.containsKey('deviceId')) {
              mapCopy['deviceId'] = key;
            }

            _log('Map data found for: ${mapCopy['deviceId']}');
            auctionsList.add(mapCopy);
          } catch (e) {
            _log('Error processing data: $e');
          }
        }
      }

      // Process and return the auction entries
      final result = _processAuctionEntries(auctionsList);
      _log('Processed ${result.length} auctions from Web3Service');
      _log('Auction IDs from _fetchAuctions: ${result.map((a) => a.deviceId).join(', ')}');
      return result;
    } catch (e, stack) {
      _log('Error fetching auctions: $e\n$stack');
      return [];
    }
  }

  /// Group auctions by their base device ID
  Map<String, List<Auction>> _groupAuctionsByBaseDevice(List<Auction> auctions) {
    _log('Grouping ${auctions.length} auctions by base device ID');

    final Map<String, List<Auction>> result = {};

    for (final auction in auctions) {
      final deviceId = _extractBaseDeviceId(auction.deviceId);
      _log('Grouping auction ${auction.deviceId} -> base: $deviceId');

      result.putIfAbsent(deviceId, () => []);
      result[deviceId]!.add(auction);
    }

    // Sort each group by start time
    result.forEach((key, slots) {
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    return result;
  }

  /// Extract the base device ID from a session-specific device ID
  String _extractBaseDeviceId(String deviceId) {
    _log('Extracting base device ID from: $deviceId');

    // Check for various formats: deviceId-session-X, deviceId::timestamp, etc.
    if (deviceId.contains('-session-')) {
      // Handle the multi-slot format: sessionName-session-timestamp-slot-i
      if (deviceId.contains('-slot-')) {
        // Extract the part before the timestamp (sessionName)
        final parts = deviceId.split('-session-');
        if (parts.isNotEmpty) {
          final baseId = parts[0];
          _log('  Extracted base ID (multi-slot format): $baseId');
          return baseId;
        }
      }
      
      // Standard session format
      final baseId = deviceId.split('-session-')[0];
      _log('  Extracted base ID (session format): $baseId');
      return baseId;
    } else if (deviceId.contains('::')) {
      final baseId = deviceId.split('::')[0];
      _log('  Extracted base ID (timestamp format): $baseId');
      return baseId;
    }

    // For user-created auctions or other formats, return as is
    _log('  No special format detected, using as is: $deviceId');
    return deviceId;
  }

  /// Build a card for displaying a device with multiple auction slots
  Widget _buildDeviceAuctionCard(String deviceId, List<Auction> slots) {
    final web3Service = Provider.of<Web3Service>(context, listen: false);

    // Sort slots by start time
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                
                // Use the actual slot times from additionalData if available
                DateTime slotStartTime = slot.startTime;
                DateTime slotEndTime = slot.endTime;
                
                if (slot.additionalData.containsKey('actualSlotStartTime') && 
                    slot.additionalData.containsKey('actualSlotEndTime')) {
                  try {
                    slotStartTime = DateTime.parse(slot.additionalData['actualSlotStartTime']);
                    slotEndTime = DateTime.parse(slot.additionalData['actualSlotEndTime']);
                    
                    // Ensure slot is exactly 5 minutes long regardless of what's stored
                    // This fixes any potential rounding errors in datetime calculations
                    slotEndTime = slotStartTime.add(const Duration(minutes: 5));
                    
                    _log('Using actual slot times: $slotStartTime - $slotEndTime');
                  } catch (e) {
                    _log('Error parsing actual slot times: $e');
                  }
                } else {
                  // For legacy auctions, ensure displayed duration is 5 minutes
                  slotEndTime = slotStartTime.add(const Duration(minutes: 5));
                  _log('Using default 5-minute slot: $slotStartTime - $slotEndTime');
                }
                
                // Check if bidding has ended based on the biddingEndTime from the smart contract
                bool hasBiddingEnded = false;
                if (slot.additionalData.containsKey('biddingEndTime')) {
                  // Use biddingEndTime from contract if available
                  final DateTime biddingEndTime = DateTime.parse(slot.additionalData['biddingEndTime']);
                  hasBiddingEnded = now.isAfter(biddingEndTime);
                  _log('Bidding end time from contract: $biddingEndTime, has ended: $hasBiddingEnded');
                } else {
                  // Fallback: Use the standard 5-minute before start rule
                  final DateTime estimatedBiddingEndTime = slotStartTime.subtract(const Duration(minutes: 5));
                  hasBiddingEnded = now.isAfter(estimatedBiddingEndTime);
                  _log('Using estimated bidding end time: $estimatedBiddingEndTime, has ended: $hasBiddingEnded');
                }
                
                // Check if the slot is currently active or has ended based on actual slot times
                final isActive = slotStartTime.isBefore(now) && slotEndTime.isAfter(now);
                final hasEnded = slotEndTime.isBefore(now);
                
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
                                'Slot ${index + 1}: ${_formatDateTime(slotStartTime)} - ${_formatDateTime(slotEndTime)} (5m)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              // Add a warning label if we're in the period where bidding might end soon
                              // Only show if bidding hasn't already ended
                              if (!hasEnded && !isActive && !hasBiddingEnded && slotStartTime.difference(now).inMinutes < 5)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(_isWarningVisible ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red.withOpacity(_isWarningVisible ? 1.0 : 0.5),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'BIDDING ENDING SOON',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
                                  // Only show bid button for upcoming (not active, not ended) slots that aren't finalized
                                  if (!slot.isFinalized && !hasEnded && !isActive)
                                    ElevatedButton(
                                      onPressed: hasBiddingEnded ? null : () {
                                        final slotTimeRemaining = slotStartTime.difference(now);
                                        
                                        if (hasBiddingEnded || slotTimeRemaining.inMinutes < 1) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Bidding has ended for this slot'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } else {
                                          _bidOnAuction(slot);
                                        }
                                      },
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

  int _calculateDurationInMinutes(DateTime startTime, DateTime endTime) {
    return endTime.difference(startTime).inMinutes;
  }

  /// Method to refresh auction data
  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _isLoading = true;
    });

    try {
      // Get the web3 service
      final web3Service = Provider.of<Web3Service>(context, listen: false);

      // Force a refresh of auctions
      if (forceRefresh) {
        _log('Forcing refresh of auctions from web3Service');
        await web3Service.loadActiveAuctions(forceRefresh: true);
      }

      // Update the cached future
      _log('Refreshing auctions future');
      await _refreshAuctions();
      
      // Pre-fetch the auctions to process them
      final auctions = await _cachedAuctionsFuture!;
      _log('Pre-fetched ${auctions.length} auctions for UI update');

      if (mounted) {
        setState(() {
          _auctions = auctions;
          _isRefreshing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Error refreshing data: $e');

      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Log a message with the AuctionScreen prefix
  void _log(String message) {
    if (kDebugMode) {
      print('AuctionScreen: $message');
      developer.log(message, name: 'AuctionScreen');
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
    // For slot display, show hours and minutes but also add a more detailed format with seconds
    // This helps debug if slots are actually 5 minutes apart
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    _log('Formatting time: $dateTime -> $time');
    return time;
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
    _log('Error creating auction: $e');

    String errorMessage = 'Failed to create auction: $e';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Submit the auction creation form
  Future<void> _submitAuctionForm() async {
    // Get scaffold messenger for snackbars
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Get required form data
    final deviceId = _deviceIdController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      // Get services
      final web3Service = context.read<Web3Service>();

      // Validate inputs
      if (deviceId.isEmpty) {
        throw Exception('Device ID is required');
      }

      if (_minimumBidController.text.isEmpty) {
        throw Exception('Minimum bid is required');
      }

      // Parse values
      final double minimumBid = double.parse(_minimumBidController.text);

      // Calculate number of slots based on duration (5 minutes per slot)
      final int numSlots = _selectedSlotDuration ~/ 5;

      // Calculate start time (1 minute from now)
      final now = DateTime.now();
      final DateTime startTime = now.add(const Duration(minutes: 1));

      _log('Creating multi-slot auction with device: $deviceId, min bid: $minimumBid, duration: $_selectedSlotDuration minutes, slots: $numSlots');

      // Create a MultiSlotAuctionService
      final multiSlotService = MultiSlotAuctionService(web3Service);
      
      // Create multi-slot auction
      final result = await multiSlotService.createMultiSlotAuction(
        sessionName: deviceId,
        startTime: startTime,
        slotDurationMinutes: 5, // Fixed 5-minute slots
        slotCount: numSlots, // Multiple slots based on total duration
        minimumBid: minimumBid,
      );

      _log('Multi-slot auction creation result: ${result.success}');
      _log('Result message: ${result.message}');

      // Reset form
      _deviceIdController.clear();
      _minimumBidController.clear();

      // Force a complete refresh of the active auctions
      _log('Before loadActiveAuctions - active auctions count: ${web3Service.activeAuctions.length}');
      _log('Active auction keys: ${web3Service.activeAuctions.keys.join(', ')}');

      await web3Service.loadActiveAuctions(forceRefresh: true);

      _log('After loadActiveAuctions - active auctions count: ${web3Service.activeAuctions.length}');
      _log('Active auction keys: ${web3Service.activeAuctions.keys.join(', ')}');

      // Display success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Successfully created auction with $numSlots slots'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to the active auctions tab
      _tabController.animateTo(1);
      
      // Refresh the UI to show new auctions
      setState(() {
        _isLoading = false;
      });
      
      // Trigger a refresh to update the auctions list
      _refreshData(forceRefresh: true);
    } catch (e) {
      String errorMessage = 'Failed to create auction: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Highlight newly created auction in the list (visual feedback)
  void _highlightNewlyCreatedAuction(String deviceId) {
    _log('Highlighting newly created auction: $deviceId');

    // Find the auction in the list
    final index = _auctions.indexWhere((a) => a.deviceId == deviceId);

    if (index >= 0) {
      _log('Found auction at index $index');

      // Scroll to the auction
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Calculate the position of the widget
          final itemHeight = 150.0; // Approximate height of each item
          final offset = index * itemHeight;

          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });

      // Flash animation can be implemented here if needed
    } else {
      _log('Auction not found in list');
    }
  }

  /// Method to check if we're in mock mode and ensure it's properly setup
  void _checkAndCreateMockAuctions() {
    // Use Future.microtask to avoid calling setState during build
    Future.microtask(() async {
      final web3Service = context.read<Web3Service>();

      _log('Checking for mock mode: ${web3Service.isMockMode}');
      if (web3Service.isMockMode) {
        _log('Mock mode detected, ensuring it is properly setup');

        // Force enable mock mode (this no longer creates auctions by default)
        await web3Service.forceEnableMockMode();
        
        // Get current auctions (just for logging purposes)
        final result = await web3Service.getActiveAuctions();
        _log('Active auctions result: success=${result.success}, count=${result.data?.length ?? 0}');

        // Note: We no longer automatically create mock auctions
        // This ensures only user-created auctions appear in the UI
      }
    });
  }

  /// Method to handle bidding on an auction
  void _bidOnAuction(Auction auction) {
    _showBidDialog(
      context,
      auction,
      Provider.of<Web3Service>(context, listen: false),
      _refreshData,
    );
  }

  /// Method to handle finalizing an auction slot
  void _finalizeAuctionSlot(String auctionId) {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
    _finalizeAuction(web3Service, auctionId);
  }

  /// Show dialog for placing a bid
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
    });

    try {
      // Create the transaction
      final metaTxProvider = Provider.of<MetaTransactionProvider>(context, listen: false);

      await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'placeBid(string,uint256)',
        functionParams: [auction.deviceId, (result * 1e18).toInt()],
        description: 'Bid $result ETH on auction ${auction.deviceId}',
      );

      // Show a subtle confirmation that the bid was submitted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bid submitted!'),
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

      // Refresh auctions after a short delay to allow transaction to process
      Future.delayed(const Duration(seconds: 2), refreshData);
    } catch (e) {
      String errorMessage = 'Failed to place bid: ${e.toString()}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
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

  /// Method to handle finalizing an auction
  Future<void> _finalizeAuction(Web3Service web3, String deviceId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create the transaction
      final metaTxProvider = Provider.of<MetaTransactionProvider>(context, listen: false);

      await metaTxProvider.executeFunction(
        targetContract: web3.getContractAddress(),
        functionSignature: 'finalizeAuction(string)',
        functionParams: [deviceId],
        description: 'Finalize auction for device $deviceId',
      );

      // Show a subtle confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finalization submitted!'),
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

      // Refresh auctions after a delay
      Future.delayed(const Duration(seconds: 2), _refreshData);
    } catch (e) {
      String errorMessage = 'Failed to finalize auction: ${e.toString()}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
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
                  Navigator.of(context).pop();
                  await web3Service.forceEnableMockMode();

                  // Refresh the UI
                  if (mounted) {
                    _refreshData();
                  }
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}
