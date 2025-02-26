import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import 'auction_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Auctions'),
      ),
      body: auctions.isEmpty
          ? const Center(
              child: Text('No active auctions found'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: auctions.length,
              itemBuilder: (context, index) {
                final deviceId = auctions.keys.elementAt(index);
                final auction = auctions[deviceId]!;
                final currentBid = auction['highestBid'] as BigInt;
                final endTime = auction['endTime'] as DateTime;

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
