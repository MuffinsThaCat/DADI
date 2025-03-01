import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import 'auction_screen.dart';
import '../widgets/wavy_background.dart';

class AuctionListScreen extends StatelessWidget {
  const AuctionListScreen({super.key});

  void _navigateToAuction(BuildContext context, String deviceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuctionScreen(deviceId: deviceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final web3Service = Provider.of<Web3Service>(context);
    final auctions = web3Service.activeAuctions;
    final theme = Theme.of(context);

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
                        const Text('No active auctions found'),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: auctions.length,
                    itemBuilder: (context, index) {
                      final deviceId = auctions.keys.elementAt(index);
                      final auction = auctions[deviceId]!;
                      
                      // Handle currentBid safely
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
                        developer.log('Error parsing highestBid: $e');
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

                      return Card(
                        child: ListTile(
                          title: Text('Device: $deviceId'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Bid: ${_formatEther(currentBid)} ETH'),
                              Text('Ends: ${_formatDateTime(endTime)}'),
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
