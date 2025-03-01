import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meta_transaction_provider.dart';

/// Widget to display meta-transaction history
class MetaTransactionHistory extends StatelessWidget {
  /// Constructor
  const MetaTransactionHistory({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MetaTransactionProvider>(context);
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No transaction history yet',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: provider.clearHistory,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionListItem(transaction: tx);
            },
          ),
        ),
      ],
    );
  }
}

/// Widget to display a single transaction in the list
class _TransactionListItem extends StatelessWidget {
  final MetaTransaction transaction;

  const _TransactionListItem({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transaction.description,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${_getStatusText()}',
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${dateFormat.format(transaction.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (transaction.txHash != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'TX: ${_formatTxHash(transaction.txHash!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      // In a real app, this would copy to clipboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction hash copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ],
            if (transaction.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: Text(
                  transaction.error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format transaction hash for display
  String _formatTxHash(String hash) {
    if (hash.length <= 14) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  /// Get appropriate icon for transaction status
  Widget _getStatusIcon() {
    switch (transaction.status) {
      case MetaTransactionStatus.submitted:
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      case MetaTransactionStatus.processing:
        return const Icon(Icons.sync, color: Colors.blue);
      case MetaTransactionStatus.confirmed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MetaTransactionStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case MetaTransactionStatus.unknown:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  /// Get text description of transaction status
  String _getStatusText() {
    switch (transaction.status) {
      case MetaTransactionStatus.submitted:
        return 'Submitted';
      case MetaTransactionStatus.processing:
        return 'Processing';
      case MetaTransactionStatus.confirmed:
        return 'Confirmed';
      case MetaTransactionStatus.failed:
        return 'Failed';
      case MetaTransactionStatus.unknown:
        return 'Unknown';
    }
  }

  /// Get color for transaction status
  Color _getStatusColor() {
    switch (transaction.status) {
      case MetaTransactionStatus.submitted:
        return Colors.orange;
      case MetaTransactionStatus.processing:
        return Colors.blue;
      case MetaTransactionStatus.confirmed:
        return Colors.green;
      case MetaTransactionStatus.failed:
        return Colors.red;
      case MetaTransactionStatus.unknown:
        return Colors.grey;
    }
  }
}
