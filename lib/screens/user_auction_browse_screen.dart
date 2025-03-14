import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../models/user_role.dart';
import '../providers/user_role_provider.dart';
import '../widgets/wavy_background.dart';
import 'auction_screen.dart';
import 'wallet_screen.dart';
import '../services/mock_buttplug_service.dart';

class UserAuctionBrowseScreen extends StatefulWidget {
  const UserAuctionBrowseScreen({Key? key}) : super(key: key);

  @override
  State<UserAuctionBrowseScreen> createState() => _UserAuctionBrowseScreenState();
}

class _UserAuctionBrowseScreenState extends State<UserAuctionBrowseScreen> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final web3 = Provider.of<Web3Service>(context);
    final roleProvider = Provider.of<UserRoleProvider>(context);
    final buttplugService = Provider.of<MockButtplugService>(context);
    
    // Get all auctions for browsing
    final browseAuctions = web3.activeAuctions.entries
        .toList();
    
    // Group auctions by base device ID (for multi-slot auctions)
    final groupedAuctions = <String, List<MapEntry<String, Map<String, dynamic>>>>{};
    
    for (var auction in browseAuctions) {
      // Check if this is a session-based auction
      final deviceId = auction.key;
      final parts = deviceId.split('-session-');
      
      if (parts.length > 1) {
        // This is a session, group by base device ID
        final baseDeviceId = parts[0];
        groupedAuctions.putIfAbsent(baseDeviceId, () => []);
        groupedAuctions[baseDeviceId]!.add(auction);
      } else {
        // This is a regular auction, treat as a single-item group
        groupedAuctions.putIfAbsent(deviceId, () => []);
        groupedAuctions[deviceId]!.add(auction);
      }
    }
    
    // Convert grouped auctions to a list for display
    final displayAuctions = groupedAuctions.entries.map((entry) {
      // Use the first auction's data for the display card
      final baseDeviceId = entry.key;
      final firstAuction = entry.value.first;
      
      // Return a MapEntry with the base device ID and the first auction's data
      return MapEntry(baseDeviceId, firstAuction.value);
    }).toList();
    
    // Filter by search query if provided
    final filteredAuctions = _searchQuery.isEmpty
        ? displayAuctions
        : displayAuctions.where((auction) =>
            auction.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Browse Auctions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roleProvider.role.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
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
          // Device connection button
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
        primaryColor: theme.colorScheme.primary.withOpacity(0.7),
        secondaryColor: theme.colorScheme.secondary.withOpacity(0.7),
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(context),
            
            // Featured auction carousel
            if (filteredAuctions.isNotEmpty)
              _buildFeaturedAuctions(context, filteredAuctions),
              
            // All auctions grid
            Expanded(
              child: _buildAuctionsGrid(context, filteredAuctions),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search auctions...',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedAuctions(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> auctions) {
    // Sort by highest bid
    final sortedAuctions = List<MapEntry<String, Map<String, dynamic>>>.from(auctions);
    sortedAuctions.sort((a, b) {
      final bidA = _getBigIntValue(a.value['highestBid']);
      final bidB = _getBigIntValue(b.value['highestBid']);
      return bidB.compareTo(bidA);
    });
    
    // Take top 3 auctions
    final featuredAuctions = sortedAuctions.take(3).toList();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Featured Auctions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: featuredAuctions.length,
              itemBuilder: (context, index) {
                final deviceId = featuredAuctions[index].key;
                final auction = featuredAuctions[index].value;
                
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToAuctionDetails(context, deviceId),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.devices,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    deviceId,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Minimum Bid',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatEther(_getBigIntValue(auction['minBid']))} ETH',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _navigateToAuctionDetails(context, deviceId),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Bid Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionsGrid(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> auctions) {
    if (auctions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No auctions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try changing your search query',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'All Auctions (${auctions.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: auctions.length,
              itemBuilder: (context, index) {
                final deviceId = auctions[index].key;
                final auction = auctions[index].value;
                
                // Calculate time remaining
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
                
                final now = DateTime.now();
                final remainingTime = endTime.difference(now);
                final isEndingSoon = remainingTime.inHours < 12 && remainingTime.inHours >= 0;
                
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _navigateToAuctionDetails(context, deviceId),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.devices,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            deviceId,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatEther(_getBigIntValue(auction['highestBid']))} ETH',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (isEndingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ending Soon',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _navigateToAuctionDetails(context, deviceId),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Bid Now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        // Handle navigation
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Browse',
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

  BigInt _getBigIntValue(dynamic value) {
    try {
      if (value is BigInt) {
        return value;
      } else if (value is int) {
        return BigInt.from(value);
      } else if (value is String) {
        return BigInt.parse(value);
      } else {
        return BigInt.zero;
      }
    } catch (e) {
      return BigInt.zero;
    }
  }

  String _formatEther(BigInt wei) {
    return (wei / BigInt.from(1e18)).toStringAsFixed(4);
  }

  void _navigateToAuctionDetails(BuildContext context, String deviceId) {
    // Get the web3 service
    final web3 = Provider.of<Web3Service>(context, listen: false);
    
    // Find all sessions for this device
    final sessionAuctions = web3.activeAuctions.entries
        .where((entry) => entry.key.startsWith('$deviceId-session-') || entry.key == deviceId)
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList();
    
    if (sessionAuctions.isEmpty) {
      // Fallback to showing just this auction if no sessions found
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuctionScreen(
            deviceId: deviceId,
            showOnlySpecificDevice: true,
          ),
        ),
      );
    } else {
      // Show only the sessions for this specific device
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuctionScreen(
            deviceId: deviceId,
            showOnlySpecificDevice: true,
            preFilteredSessions: sessionAuctions,
          ),
        ),
      );
    }
  }
}
