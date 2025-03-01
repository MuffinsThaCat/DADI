import 'package:flutter/material.dart';
import '../providers/meta_transaction_provider.dart';

/// Widget to display the status of a meta-transaction with real-time updates
class TransactionStatusWidget extends StatelessWidget {
  /// The transaction to display
  final MetaTransaction transaction;
  
  /// Whether to use compact mode (card with minimal info) or detailed mode
  final bool compact;
  
  /// Whether to use web-specific styling (more subtle for web platforms)
  final bool useWebStyling;
  
  /// Whether to show a link to the block explorer
  final bool showBlockExplorerLink;
  
  /// URL of the block explorer (e.g., 'https://snowtrace.io/tx/')
  final String? blockExplorerUrl;

  const TransactionStatusWidget({
    super.key,
    required this.transaction,
    this.compact = true,
    this.useWebStyling = false,
    this.showBlockExplorerLink = false,
    this.blockExplorerUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (transaction.status) {
      case MetaTransactionStatus.submitted:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Submitted';
        break;
      case MetaTransactionStatus.processing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Processing';
        break;
      case MetaTransactionStatus.confirmed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Confirmed';
        break;
      case MetaTransactionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      case MetaTransactionStatus.unknown:
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Unknown';
        break;
    }
    
    // Compact version just shows a card with basic info
    if (compact) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Status icon
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              
              // Transaction description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.txHash != null)
                      Text(
                        'TX: ${transaction.txHash!.substring(0, 10)}...',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              
              // Status text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Full version with more details
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  transaction.description,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            const Divider(),
            
            // Transaction details
            if (transaction.txHash != null) ...[
              _buildDetailRow('Transaction Hash', transaction.txHash!),
            ],
            _buildDetailRow('Target Contract', transaction.targetContract),
            _buildDetailRow('Function', transaction.functionSignature),
            _buildDetailRow('Time', _formatDateTime(transaction.timestamp)),
            
            // Error message if failed
            if (transaction.status == MetaTransactionStatus.failed && transaction.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Error: ${transaction.error}',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            
            // Block explorer link
            if (showBlockExplorerLink && blockExplorerUrl != null && transaction.txHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton(
                  onPressed: () {
                    // Open block explorer link
                  },
                  child: Text(
                    'View on ${blockExplorerUrl!.split('/').last}',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
