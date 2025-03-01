import 'package:flutter/material.dart';
import '../models/wallet_transaction.dart';

/// Widget for displaying a list of wallet transactions
class WalletTransactionList extends StatelessWidget {
  /// List of transactions to display
  final List<Map<String, dynamic>> transactions;

  const WalletTransactionList({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your transaction history will appear here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(context, transaction);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, Map<String, dynamic> transaction) {
    // Commented out unused variables but keeping them for future use
    // final hash = transaction['hash'] as String;
    // final from = transaction['from'] as String;
    // final to = transaction['to'] as String;
    final value = transaction['value'] as double;
    
    // Convert string status to enum
    final statusStr = transaction['status'] as String;
    final TransactionStatus status = statusStr == 'confirmed' 
        ? TransactionStatus.confirmed 
        : statusStr == 'failed' 
            ? TransactionStatus.failed 
            : TransactionStatus.pending;
    
    // Convert string type to enum
    final typeStr = transaction['type'] as String;
    final TransactionType type = typeStr == 'send' 
        ? TransactionType.send 
        : typeStr == 'contractCall' 
            ? TransactionType.contractCall 
            : TransactionType.receive;
            
    final timestamp = DateTime.parse(transaction['timestamp'] as String);
    
    // Format timestamp
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    String timeDisplay;
    
    if (difference.inDays > 365) {
      timeDisplay = '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      timeDisplay = '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      timeDisplay = '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      timeDisplay = '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      timeDisplay = '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      timeDisplay = 'Just now';
    }
    
    // Determine icon and color based on transaction type and status
    IconData icon;
    Color iconColor;
    Color backgroundColor;
    
    if (type == TransactionType.send) {
      icon = Icons.arrow_upward;
      iconColor = Colors.white;
      backgroundColor = Colors.red.shade400;
    } else if (type == TransactionType.receive) {
      icon = Icons.arrow_downward;
      iconColor = Colors.white;
      backgroundColor = Colors.green.shade400;
    } else if (type == TransactionType.contractCall) {
      icon = Icons.code;
      iconColor = Colors.white;
      backgroundColor = Colors.purple.shade400;
    } else {
      icon = Icons.swap_horiz;
      iconColor = Colors.white;
      backgroundColor = Colors.blue.shade400;
    }
    
    // Determine status text and color
    String statusText;
    Color statusColor;
    
    switch (status) {
      case TransactionStatus.pending:
        statusText = 'Pending';
        statusColor = Colors.orange;
        break;
      case TransactionStatus.confirmed:
        statusText = 'Confirmed';
        statusColor = Colors.green;
        break;
      case TransactionStatus.failed:
        statusText = 'Failed';
        statusColor = Colors.red;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
    }
    
    return InkWell(
      onTap: () => _showTransactionDetails(context, transaction),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type == TransactionType.send ? 'Sent ETH' :
                        type == TransactionType.receive ? 'Received ETH' :
                        type == TransactionType.contractCall ? 'Contract Call' : 'Other',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${value.toStringAsFixed(6)} ETH',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: type == TransactionType.send ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    final hash = transaction['hash'] as String;
    final from = transaction['from'] as String;
    final to = transaction['to'] as String;
    final value = transaction['value'] as double;
    final statusStr = transaction['status'] as String;
    final TransactionStatus status = statusStr == 'confirmed' 
        ? TransactionStatus.confirmed 
        : statusStr == 'failed' 
            ? TransactionStatus.failed 
            : TransactionStatus.pending;
    final typeStr = transaction['type'] as String;
    final TransactionType type = typeStr == 'send' 
        ? TransactionType.send 
        : typeStr == 'contractCall' 
            ? TransactionType.contractCall 
            : TransactionType.receive;
    final timestamp = DateTime.parse(transaction['timestamp'] as String);
    
    // Format timestamp
    final dateFormat = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', type == TransactionType.send ? 'Sent' : type == TransactionType.receive ? 'Received' : 'Contract Call'),
              _buildDetailRow('Status', status == TransactionStatus.pending ? 'Pending' : status == TransactionStatus.confirmed ? 'Confirmed' : 'Failed'),
              _buildDetailRow('Amount', '${value.toStringAsFixed(6)} ETH'),
              _buildDetailRow('Date', dateFormat),
              _buildDetailRow('From', _formatAddressForDisplay(from)),
              _buildDetailRow('To', _formatAddressForDisplay(to)),
              _buildDetailRow('Hash', _formatAddressForDisplay(hash)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddressForDisplay(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
