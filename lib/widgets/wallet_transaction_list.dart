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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(context, transaction);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, Map<String, dynamic> transaction) {
    final hash = transaction['hash'] as String;
    final from = transaction['from'] as String;
    final to = transaction['to'] as String;
    final value = transaction['value'] as double;
    final status = TransactionStatus.values[transaction['status'] as int];
    final type = TransactionType.values[transaction['type'] as int];
    final timestamp = DateTime.parse(transaction['timestamp'] as String);
    
    // Format timestamp
    final dateFormat = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    // Determine icon and color based on transaction type and status
    IconData icon;
    Color iconColor;
    
    if (type == TransactionType.send) {
      icon = Icons.arrow_upward;
      iconColor = Colors.red;
    } else if (type == TransactionType.receive) {
      icon = Icons.arrow_downward;
      iconColor = Colors.green;
    } else {
      icon = Icons.receipt_long;
      iconColor = Colors.blue;
    }
    
    // Status indicator
    Widget statusIndicator;
    if (status == TransactionStatus.pending) {
      statusIndicator = const Chip(
        label: Text('Pending'),
        backgroundColor: Colors.amber,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else if (status == TransactionStatus.confirmed) {
      statusIndicator = const Chip(
        label: Text('Confirmed'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else {
      statusIndicator = const Chip(
        label: Text('Failed'),
        backgroundColor: Colors.red,
        labelStyle: TextStyle(color: Colors.white),
      );
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(
            icon,
            color: iconColor,
          ),
        ),
        title: Row(
          children: [
            Text(
              type == TransactionType.send ? 'Sent' : type == TransactionType.receive ? 'Received' : 'Contract Call',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${type == TransactionType.send ? '-' : type == TransactionType.receive ? '+' : ''}${value.toStringAsFixed(6)} ETH',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: type == TransactionType.send ? Colors.red : type == TransactionType.receive ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(dateFormat),
                const Spacer(),
                statusIndicator,
              ],
            ),
            const SizedBox(height: 4),
            Text('To: ${_formatAddress(to)}'),
            if (type != TransactionType.receive)
              Text('From: ${_formatAddress(from)}'),
            Text('Tx: ${_formatAddress(hash)}'),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showTransactionDetails(context, transaction),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    final hash = transaction['hash'] as String;
    final from = transaction['from'] as String;
    final to = transaction['to'] as String;
    final value = transaction['value'] as double;
    final gasPrice = transaction['gasPrice'] as double;
    final gasUsed = transaction['gasUsed'] as int?;
    final status = TransactionStatus.values[transaction['status'] as int];
    final type = TransactionType.values[transaction['type'] as int];
    final timestamp = DateTime.parse(transaction['timestamp'] as String);
    final blockNumber = transaction['blockNumber'] as int?;
    final contractAddress = transaction['contractAddress'] as String?;
    final functionName = transaction['functionName'] as String?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailItem('Hash', hash),
              _detailItem('From', from),
              _detailItem('To', to),
              if (contractAddress != null)
                _detailItem('Contract', contractAddress),
              if (functionName != null)
                _detailItem('Function', functionName),
              _detailItem('Value', '$value ETH'),
              _detailItem('Gas Price', '$gasPrice Gwei'),
              if (gasUsed != null)
                _detailItem('Gas Used', gasUsed.toString()),
              _detailItem('Status', status.toString().split('.').last),
              _detailItem('Type', type.toString().split('.').last),
              _detailItem('Timestamp', timestamp.toString()),
              if (blockNumber != null)
                _detailItem('Block Number', blockNumber.toString()),
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

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
