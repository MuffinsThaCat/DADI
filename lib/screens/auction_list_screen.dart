import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import 'auction_screen.dart';
import '../widgets/wavy_background.dart';

class AuctionListScreen extends StatefulWidget {
  const AuctionListScreen({super.key});

  @override
  State<AuctionListScreen> createState() => _AuctionListScreenState();
}

class _AuctionListScreenState extends State<AuctionListScreen> {
  void _navigateToAuction(BuildContext context, String deviceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuctionScreen(deviceId: deviceId),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Schedule a post-frame callback to fetch auctions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final web3Service = Provider.of<Web3Service>(context, listen: false);
      web3Service.getActiveAuctions();
      developer.log('Fetching auctions in initState', name: 'AuctionList');
    });
  }

  void _refreshAuctions() {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
    web3Service.getActiveAuctions();
    setState(() {
      // Trigger rebuild
    });
    developer.log('Manual refresh completed', name: 'AuctionList');
  }

  @override
  Widget build(BuildContext context) {
    final web3Service = Provider.of<Web3Service>(context);
    final auctions = web3Service.activeAuctions;
    final theme = Theme.of(context);
    
    developer.log('AuctionListScreen build called, auction count: ${auctions.length}', name: 'AuctionList');
    
    // Log all available auctions for debugging
    auctions.forEach((key, value) {
      developer.log('Available auction: $key, isUserCreated: ${value['isUserCreated']}', name: 'AuctionList');
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Active Auctions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAuctions,
          ),
        ],
      ),
      body: WavyBackground(
        primaryColor: theme.colorScheme.primary,
        secondaryColor: theme.colorScheme.secondary,
        child: Column(
          children: [
            // Auction list
            Expanded(
              child: auctions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No active auctions found'),
                        SizedBox(height: 16),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: auctions.length,
                    itemBuilder: (context, index) {
                      final deviceId = auctions.keys.elementAt(index);
                      final auction = auctions[deviceId]!;
                      
                      // Debug logging to see auction structure
                      developer.log('AUCTION LIST: Processing auction: $deviceId', name: 'AuctionList');
                      developer.log('AUCTION LIST: Structure: ${auction.keys.toList().join(', ')}', name: 'AuctionList');
                      developer.log('AUCTION LIST: Owner: ${auction['owner']}', name: 'AuctionList');
                      developer.log('AUCTION LIST: Fields: ${auction.toString()}', name: 'AuctionList');
                      
                      // Handle currentBid safely
                      BigInt currentBid;
                      try {
                        if (auction['highestBid'] is BigInt) {
                          currentBid = auction['highestBid'] as BigInt;
                        } else if (auction['highestBid'] is int) {
                          currentBid = BigInt.from(auction['highestBid'] as int);
                        } else if (auction['highestBid'] is double) {
                          // Convert double to BigInt by treating it as wei
                          currentBid = BigInt.from((auction['highestBid'] as double) * 1e18);
                        } else if (auction['highestBid'] is String) {
                          currentBid = BigInt.parse(auction['highestBid'] as String);
                        } else {
                          currentBid = BigInt.zero;
                        }
                      } catch (e) {
                        currentBid = BigInt.zero;
                        developer.log('Error parsing highestBid: $e', name: 'AuctionList');
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

                      // User-created flag
                      final isUserCreated = auction['isUserCreated'] == true;

                      return Card(
                        child: ListTile(
                          title: Text('Device: $deviceId'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Bid: ${_formatEther(currentBid)} ETH'),
                              Text('Ends: ${_formatDateTime(endTime)}'),
                              if (isUserCreated) 
                                const Text('User Created', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          onTap: () => _navigateToAuction(context, deviceId),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEther(BigInt wei) {
    return (wei / BigInt.from(1e18)).toStringAsFixed(4);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
