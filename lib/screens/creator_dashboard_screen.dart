import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import '../widgets/wavy_background.dart';
import 'wallet_screen.dart';
import 'auction_screen.dart';
import 'dart:developer' as developer;
import 'user_auction_browse_screen.dart';

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Force reload auctions when dashboard is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final web3 = Provider.of<Web3Service>(context, listen: false);
      developer.log('Forcing reload of auctions in dashboard initState', name: 'CreatorDashboard');
      web3.loadActiveAuctions();
    });
    
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
    
    // Get appropriate content based on navigation index
    Widget bodyContent;
    if (_selectedNavIndex == 0) {
      // Creator view
      bodyContent = Stack(
        children: [
          const WavyBackground(
            primaryColor: Colors.purple,
            secondaryColor: Colors.purpleAccent,
            child: SizedBox.expand(),
          ),
          TabBarView(
            controller: _tabController,
            children: [
              // All auctions tab
              _buildAuctionsList(type: 'all'),
              // Active auctions tab
              _buildAuctionsList(type: 'active'),
              // Completed auctions tab
              _buildAuctionsList(type: 'completed'),
            ],
          ),
        ],
      );
    } else if (_selectedNavIndex == 1) {
      // Bidder view
      bodyContent = Stack(
        children: [
          const WavyBackground(
            primaryColor: Colors.blue,
            secondaryColor: Colors.blueAccent,
            child: SizedBox.expand(),
          ),
          Center(
            child: Text(
              'Bid Dashboard\nComing Soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else {
      // Profile view
      bodyContent = Stack(
        children: [
          const WavyBackground(
            primaryColor: Colors.green,
            secondaryColor: Colors.greenAccent,
            child: SizedBox.expand(),
          ),
          Center(
            child: Text(
              'Profile Screen\nComing Soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedNavIndex == 0 ? 'Creator Dashboard' : 
                   _selectedNavIndex == 1 ? 'Bid Dashboard' : 'Profile'),
        backgroundColor: _selectedNavIndex == 0 ? Colors.purple.shade100 : 
                        _selectedNavIndex == 1 ? Colors.blue.shade100 : Colors.green.shade100,
        automaticallyImplyLeading: false, // Disable back button
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
          ),
        ],
        bottom: _selectedNavIndex == 0 ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ) : null,
      ),
      body: bodyContent,
      floatingActionButton: _selectedNavIndex == 0 ? FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AuctionScreen(),
            ),
          );
          
          // Refresh the auctions list when returning from the auction screen
          _forceRefreshAuctions();
        },
        child: const Icon(Icons.add),
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Creator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Bid',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
      ),
    );
  }
  
  void _onNavItemTapped(int index) {
    if (index != _selectedNavIndex) {
      // If user clicked the "Bid" tab (index 1), switch to User role and navigate
      if (index == 1) {
        // Navigate to the UserAuctionBrowseScreen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const UserAuctionBrowseScreen(),
          ),
        );
        
        // Do not update the selected index since we're navigating away
        return;
      }
      
      // For other tabs, just update the index as normal
      setState(() {
        _selectedNavIndex = index;
      });
      
      developer.log('Bottom navigation index changed to: $index', name: 'CreatorDashboard');
    }
  }
  
  Future<void> _forceRefreshAuctions() async {
    final web3 = Provider.of<Web3Service>(context, listen: false);
    developer.log('Force refreshing auctions in dashboard', name: 'CreatorDashboard');
    
    // Force reload all auctions from mock storage to ensure we have the latest data
    await web3.loadActiveAuctions(forceRefresh: true);
    
    // Debug after refresh
    developer.log('Auctions after refresh: ${web3.activeAuctions.length}', name: 'CreatorDashboard');
    web3.activeAuctions.forEach((id, data) {
      developer.log('Refreshed auction - ID: $id, Owner: ${data['owner']}, isUserCreated: ${data['isUserCreated']}', 
          name: 'CreatorDashboard');
    });
    
    if (mounted) {
      setState(() {
        // Force rebuild the widget
        // Just trigger a rebuild
      });
    }
  }
  
  Widget _buildAuctionsList({required String type}) {
    final web3 = Provider.of<Web3Service>(context);
    final userAddress = web3.currentAddress;
    
    developer.log('Building auctions list for type: $type', name: 'CreatorDashboard');
    developer.log('Current user address: $userAddress', name: 'CreatorDashboard');
    developer.log('Total active auctions: ${web3.activeAuctions.length}', name: 'CreatorDashboard');
    
    // Debug all active auctions with full details
    developer.log('************************ DEBUGGING ALL AUCTIONS ************************', name: 'CreatorDashboard');
    web3.activeAuctions.forEach((deviceId, auctionData) {
      developer.log('Auction: $deviceId', name: 'CreatorDashboard');
      auctionData.forEach((key, value) {
        developer.log('  $key: $value', name: 'CreatorDashboard');
      });
      developer.log('------------------------------------------------------------------', name: 'CreatorDashboard');
    });
    developer.log('**********************************************************************', name: 'CreatorDashboard');
    
    var myAuctions = web3.activeAuctions.entries
        .where((entry) {
          String ownerAddress = entry.value['owner']?.toString() ?? '';
          String currentUserAddress = userAddress?.toString() ?? '';
          
          bool isOwner = false;
          if (ownerAddress.isNotEmpty && currentUserAddress.isNotEmpty) {
            isOwner = ownerAddress.toLowerCase() == currentUserAddress.toLowerCase();
          }
          
          // Check if this is a user-created auction (not a preset)
          bool isUserCreated = entry.value['isUserCreated'] == true;
          
          // Log detailed filtering information
          developer.log('Filtering auction ${entry.key}:', name: 'CreatorDashboard');
          developer.log('  owner: $ownerAddress', name: 'CreatorDashboard');
          developer.log('  currentUser: $currentUserAddress', name: 'CreatorDashboard');
          developer.log('  isOwner: $isOwner', name: 'CreatorDashboard');
          developer.log('  isUserCreated: $isUserCreated', name: 'CreatorDashboard');
          developer.log('  include in results: ${isOwner || isUserCreated}', name: 'CreatorDashboard');
          
          // Return true if this is the user's auction OR it's specifically marked as user-created
          return isOwner || isUserCreated;
        })
        .toList();
    
    developer.log('My auctions count after filtering: ${myAuctions.length}', name: 'CreatorDashboard');
    
    if (myAuctions.isEmpty) {
      return const Center(
        child: Text('No auctions found. Create one now!'),
      );
    }
    
    // Group session auctions - hide the individual 5-minute sessions
    final Map<String, Map<String, dynamic>> groupedAuctions = {};
    
    for (final entry in myAuctions) {
      String deviceId = entry.key;
      Map<String, dynamic> auctionData = Map<String, dynamic>.from(entry.value);
      
      // Check if this is a session auction (has a sessionId)
      if (auctionData.containsKey('sessionId') && auctionData['sessionId'] != null) {
        String sessionId = auctionData['sessionId'].toString();
        
        // If we already have a grouping for this session, skip
        if (groupedAuctions.containsKey(sessionId)) {
          continue;
        }
        
        // Create a new group entry that represents the session
        groupedAuctions[sessionId] = {
          'deviceId': sessionId,
          'isSession': true,
          'sessionName': auctionData['sessionName'] ?? 'Session $sessionId',
          'owner': auctionData['owner'],
          'active': auctionData['active'] ?? false,
          'slotCount': myAuctions
              .where((e) => e.value['sessionId'] == sessionId)
              .length,
        };
      } else {
        // Not a session auction, add directly
        groupedAuctions[deviceId] = auctionData;
      }
    }
    
    // Filter by auction status if needed
    final List<MapEntry<String, Map<String, dynamic>>> filteredAuctions;
    
    if (type == 'all') {
      filteredAuctions = groupedAuctions.entries.toList();
    } else if (type == 'active') {
      filteredAuctions = groupedAuctions.entries
          .where((entry) => entry.value['active'] == true)
          .toList();
    } else {
      filteredAuctions = groupedAuctions.entries
          .where((entry) => entry.value['active'] == false)
          .toList();
    }
    
    developer.log('Filtered auctions count (type $type): ${filteredAuctions.length}', name: 'CreatorDashboard');
    
    return RefreshIndicator(
      onRefresh: _forceRefreshAuctions,
      child: ListView.builder(
        itemCount: filteredAuctions.length,
        itemBuilder: (context, index) {
          final entry = filteredAuctions[index];
          final deviceId = entry.key;
          final auctionData = entry.value;
          
          final bool isSession = auctionData['isSession'] == true;
          final String title = isSession
              ? auctionData['sessionName'] ?? 'Session $deviceId'
              : 'Auction $deviceId';
          
          final String ownerAddress = auctionData['owner']?.toString() ?? '';
          final bool ownerMatch = userAddress != null && 
                                 ownerAddress.isNotEmpty && 
                                 ownerAddress.toLowerCase() == userAddress.toLowerCase();
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: ownerMatch ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (ownerMatch)
                    Text(
                      'YOUR AUCTION! ',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device ID: $deviceId'),
                  isSession
                      ? Text('Number of Slots: ${auctionData['slotCount']}')
                      : Text('Status: ${auctionData['active'] == true ? 'Active' : 'Completed'}'),
                ],
              ),
              trailing: Icon(
                isSession
                    ? Icons.schedule
                    : auctionData['active'] == true
                        ? Icons.gavel
                        : Icons.check_circle,
                color: auctionData['active'] == true ? Colors.green : Colors.grey,
              ),
              onTap: () {
                // Handle tapping on an auction
                developer.log('Tapped on auction $deviceId', name: 'CreatorDashboard');
              },
            ),
          );
        },
      ),
    );
  }
}
