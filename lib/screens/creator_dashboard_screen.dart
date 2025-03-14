import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import '../widgets/wavy_background.dart';
import 'wallet_screen.dart';
import 'auction_screen.dart';
import 'dart:developer' as developer;

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Add a forced refresh of auctions when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceRefreshAuctions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final web3 = Provider.of<Web3Service>(context);
    final buttplugService = Provider.of<MockButtplugService>(context);
    
    // Add extensive debug logging
    developer.log('CreatorDashboardScreen build called', name: 'CreatorDashboard');
    developer.log('Mock mode: ${web3.isMockMode}', name: 'CreatorDashboard');
    developer.log('Current user address: ${web3.currentAddress}', name: 'CreatorDashboard');
    developer.log('Total active auctions: ${web3.activeAuctions.length}', name: 'CreatorDashboard');
    
    // DEBUG: Force print all auction details
    web3.activeAuctions.forEach((deviceId, auctionData) {
      developer.log('Auction $deviceId: ${auctionData.toString()}', name: 'CreatorDashboard');
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Dashboard'),
        backgroundColor: Colors.purple.shade100,
        actions: [
          // Wallet button
          IconButton(
            icon: Icon(
              web3.isConnected 
                  ? Icons.account_balance_wallet 
                  : Icons.account_balance_wallet_outlined,
              color: web3.isConnected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletScreen(),
                ),
              );
            },
            tooltip: web3.isConnected ? 'Disconnect Wallet' : 'Connect Wallet',
          ),
          IconButton(
            icon: Icon(
              buttplugService.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
              color: buttplugService.isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: () {
              if (buttplugService.isConnected) {
                buttplugService.disconnect();
              } else {
                buttplugService.connect();
              }
            },
            tooltip: buttplugService.isConnected
                ? 'Disconnect Device'
                : 'Connect Device',
          ),
        ],
      ),
      body: WavyBackground(
        primaryColor: Colors.purple.shade100,
        secondaryColor: Colors.purple.shade50,
        child: _getSelectedScreen(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildMyAuctionsContent();
      case 2:
        return const Center(child: Text('Settings'));
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    final buttplugService = Provider.of<MockButtplugService>(context);
    final web3 = Provider.of<Web3Service>(context);
    
    // In mock mode or when connected, we'll allow auction creation
    final bool canCreateAuction = buttplugService.isConnected || web3.isMockMode;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Creator Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome to your creator dashboard! Here you can create and manage your auctions.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: _buildCreateAuctionButton(),
                  ),
                  if (!canCreateAuction) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Connect your device to create an auction',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'My Auctions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Ended'),
                    Tab(text: 'All'),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAuctionsList(type: 'active'),
                      _buildAuctionsList(type: 'ended'),
                      _buildAuctionsList(type: 'all'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAuctionsContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Auctions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Active'),
                        Tab(text: 'Ended'),
                        Tab(text: 'All'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAuctionsList(type: 'active'),
                        _buildAuctionsList(type: 'ended'),
                        _buildAuctionsList(type: 'all'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionsList({required String type}) {
    final web3 = Provider.of<Web3Service>(context);
    final userAddress = web3.currentAddress;
    
    // Add debugging logs
    developer.log('Building auctions list with type: $type', name: 'CreatorDashboard');
    developer.log('Current user address: $userAddress', name: 'CreatorDashboard');
    developer.log('Total active auctions: ${web3.activeAuctions.length}', name: 'CreatorDashboard');
    
    // Print all auctions for debugging
    developer.log('All active auctions: ${web3.activeAuctions.keys.join(', ')}', name: 'CreatorDashboard');
    developer.log('Current user address: $userAddress', name: 'CreatorDashboard');
    
    // Log each auction owner for comparison
    web3.activeAuctions.forEach((key, value) {
      developer.log('Auction $key owner: ${value['owner']} - Matches user? ${value['owner'] == userAddress}', name: 'CreatorDashboard');
    });
    
    // Filter auctions to only show the current user's auctions
    // Explicitly filter out all known test device patterns
    final myAuctions = web3.activeAuctions.entries
        .where((entry) => 
            entry.value['owner'] == userAddress && 
            entry.key != 'device-1' && 
            entry.key != 'device-2' && 
            entry.key != 'device-3' &&
            entry.key != 'mock-device-1' && 
            entry.key != 'mock-device-2')
        .toList();
    
    developer.log('My auctions count after filtering: ${myAuctions.length}', name: 'CreatorDashboard');
    
    // Group session auctions - hide the individual 5-minute sessions
    final Map<String, Map<String, dynamic>> groupedAuctions = {};
    
    for (final auction in myAuctions) {
      // Check if this is a session auction (contains -session- in the deviceId)
      final deviceId = auction.key;
      if (deviceId.contains('-session-')) {
        // Extract the base device ID (everything before -session-)
        final baseDeviceId = deviceId.split('-session-')[0];
        
        // If we haven't seen this base device yet, create an entry
        if (!groupedAuctions.containsKey(baseDeviceId)) {
          // Create a combined auction that represents all sessions
          final combinedAuction = Map<String, dynamic>.from(auction.value);
          
          // Adjust device ID to the base device ID
          combinedAuction['deviceId'] = baseDeviceId;
          
          // Store in our grouped auctions map
          groupedAuctions[baseDeviceId] = combinedAuction;
        } else {
          // Update the end time if this session ends later
          final existingEndTime = (groupedAuctions[baseDeviceId]!['endTime'] as BigInt).toInt();
          final currentEndTime = (auction.value['endTime'] as BigInt).toInt();
          
          if (currentEndTime > existingEndTime) {
            groupedAuctions[baseDeviceId]!['endTime'] = auction.value['endTime'];
          }
        }
      } else {
        // This is not a session auction, add it as is
        groupedAuctions[deviceId] = auction.value;
      }
    }
    
    // Convert back to list format that the rest of the code expects
    final groupedAuctionsList = groupedAuctions.entries
        .map((e) => MapEntry(e.key, e.value))
        .toList();
    
    developer.log('Grouped auctions count: ${groupedAuctionsList.length}', name: 'CreatorDashboard');
    
    // Log all auctions and owners for debugging
    web3.activeAuctions.forEach((deviceId, auctionData) {
      final DateTime endTime = DateTime.fromMillisecondsSinceEpoch(
          (auctionData['endTime'] as BigInt).toInt() * 1000);
      final bool isEnded = endTime.isBefore(DateTime.now());
      
      developer.log('Auction $deviceId - Owner: ${auctionData['owner']} - Active flag: ${auctionData['active']} - Is Ended by time: $isEnded', name: 'CreatorDashboard');
    });
    
    // Force update active flag based on end time
    web3.activeAuctions.forEach((deviceId, auctionData) {
      final DateTime endTime = DateTime.fromMillisecondsSinceEpoch(
          (auctionData['endTime'] as BigInt).toInt() * 1000);
      web3.activeAuctions[deviceId]!['active'] = endTime.isAfter(DateTime.now());
    });
    
    // Further filter by auction status if needed
    final filteredAuctions = type == 'all'
        ? groupedAuctionsList
        : type == 'active'
            ? groupedAuctionsList.where((entry) => entry.value['active'] == true).toList()
            : groupedAuctionsList.where((entry) => entry.value['active'] == false).toList();

    developer.log('Filtered auctions count (type $type): ${filteredAuctions.length}', name: 'CreatorDashboard');
    
    if (filteredAuctions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No auctions found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredAuctions.length,
      itemBuilder: (context, index) {
        final entry = filteredAuctions[index];
        final deviceId = entry.key;
        final auction = entry.value;
        
        // Handle current bid safely
        BigInt currentBid;
        try {
          if (auction['highestBid'] is BigInt) {
            currentBid = auction['highestBid'] as BigInt;
          } else if (auction['highestBid'] is int) {
            currentBid = BigInt.from(auction['highestBid'] as int);
          } else if (auction['highestBid'] is String) {
            currentBid = BigInt.parse(auction['highestBid'] as String);
          } else {
            currentBid = BigInt.zero;
          }
        } catch (e) {
          currentBid = BigInt.zero;
        }
        
        // Convert to DateTime safely
        DateTime endTime;
        if (auction['endTime'] is BigInt) {
          final endTimeValue = auction['endTime'] as BigInt;
          endTime = DateTime.fromMillisecondsSinceEpoch(endTimeValue.toInt() * 1000);
        } else if (auction['endTime'] is DateTime) {
          endTime = auction['endTime'] as DateTime;
        } else if (auction['endTime'] is int) {
          final endTimeInt = auction['endTime'] as int;
          endTime = DateTime.fromMillisecondsSinceEpoch(endTimeInt * 1000);
        } else {
          // Fallback
          endTime = DateTime.now().add(const Duration(hours: 1));
        }
        
        final isActive = auction['active'] == true;
        final isFinalized = auction['finalized'] == true;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Ended',
                        style: TextStyle(
                          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isFinalized)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Finalized',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Device: $deviceId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Bid',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${_formatEther(currentBid)} ETH',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'End Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _formatDateTime(endTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AuctionScreen(deviceId: deviceId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isFinalized && !isActive)
                      ElevatedButton.icon(
                        onPressed: () {
                          // Implement finalize functionality
                          _finalizeAuction(deviceId);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Finalize'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finalizeAuction(String deviceId) async {
    final web3 = Provider.of<Web3Service>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      await web3.finalizeAuction(deviceId);
      // Close loading dialog
      navigator.pop();
      
      // Show success message
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Auction finalized successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      navigator.pop();
      
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to finalize auction: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatEther(BigInt wei) {
    // Convert wei to ether (1 ether = 10^18 wei)
    final ether = wei / BigInt.from(10).pow(18);
    return ether.toStringAsFixed(4);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCreateAuctionButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        developer.log('Create Auction button pressed', name: 'CreatorDashboard');
        // Navigate to auction screen and wait for result
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AuctionScreen(),
          ),
        );
        
        developer.log('Returned from auction screen with result: $result', name: 'CreatorDashboard');
        
        // If we got a result (auction was created), force a refresh
        if (result == true) {
          developer.log('Auction was created, refreshing...', name: 'CreatorDashboard');
          await _forceRefreshAuctions();
          
          // Force state update
          if (mounted) {
            setState(() {
              developer.log('Dashboard state updated after auction creation', name: 'CreatorDashboard');
            });
          }
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Create Auction'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WalletScreen(),
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Wallet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  // Force refresh auctions from the service
  Future<void> _forceRefreshAuctions() async {
    final web3 = Provider.of<Web3Service>(context, listen: false);
    
    // Create a test auction to confirm display logic works
    if (web3.isMockMode) {
      developer.log('Creating a test auction from dashboard...', name: 'CreatorDashboard');
      final deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
      final startTime = DateTime.now().subtract(const Duration(hours: 1));
      final endTime = DateTime.now().add(const Duration(hours: 24));
      
      web3.activeAuctions[deviceId] = {
        'deviceId': deviceId,
        'owner': web3.currentAddress,
        'startTime': startTime,
        'endTime': BigInt.from(endTime.millisecondsSinceEpoch ~/ 1000),
        'minimumBid': 0.1,
        'highestBid': BigInt.from(0),
        'highestBidder': '0x0000000000000000000000000000000000000000',
        'active': true,
        'finalized': false,
      };
      
      // Force UI update
      await web3.loadActiveAuctions();
      
      if (mounted) {
        setState(() {
          developer.log('State updated after creating test auction', name: 'CreatorDashboard');
        });
      }
    }
  }
}
