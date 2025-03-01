import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meta_transaction_provider.dart';

/// Widget to display meta-transaction quota information
class MetaTransactionQuota extends StatelessWidget {
  /// Constructor
  const MetaTransactionQuota({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MetaTransactionProvider>(context);
    final remaining = provider.remainingQuota;
    final total = provider.totalQuota;
    final resetTime = provider.quotaResetTime;
    
    // Calculate percentage used
    final percentUsed = ((total - remaining) / total * 100).round();
    
    // Format reset time
    final dateFormat = DateFormat('MMM d, h:mm a');
    final formattedResetTime = dateFormat.format(resetTime);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_gas_station, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Gasless Transaction Quota',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (total - remaining) / total,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(percentUsed)),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$remaining of $total remaining',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '$percentUsed% used',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getProgressColor(percentUsed),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Resets on $formattedResetTime',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Meta-transactions allow you to interact with the blockchain without paying gas fees. DADI covers these costs for you up to your daily quota.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get appropriate color based on percentage used
  Color _getProgressColor(int percentUsed) {
    if (percentUsed < 50) {
      return Colors.green;
    } else if (percentUsed < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
