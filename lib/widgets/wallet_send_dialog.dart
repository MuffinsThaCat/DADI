import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';

/// Dialog for sending cryptocurrency
class WalletSendDialog extends StatefulWidget {
  const WalletSendDialog({Key? key}) : super(key: key);

  @override
  State<WalletSendDialog> createState() => _WalletSendDialogState();
}

class _WalletSendDialogState extends State<WalletSendDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _gasPriceController = TextEditingController();
  bool _isLoading = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _gasPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    final balance = await walletService.balance;
    setState(() {
      _currentBalance = balance;
    });
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
      
      final toAddress = _addressController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final gasPrice = _gasPriceController.text.isEmpty
          ? null
          : double.parse(_gasPriceController.text.trim());
      
      final txHash = await walletService.sendTransaction(
        toAddress: toAddress,
        amount: amount,
        gasPrice: gasPrice,
      );

      if (mounted) {
        Navigator.pop(context, true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction sent: ${_formatHash(txHash)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send transaction: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send ETH'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Balance: $_currentBalance ETH',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Address',
                  border: OutlineInputBorder(),
                  hintText: '0x...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a recipient address';
                  }
                  if (!value.startsWith('0x') || value.length != 42) {
                    return 'Please enter a valid Ethereum address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (ETH)',
                  border: OutlineInputBorder(),
                  hintText: '0.01',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  
                  double? amount;
                  try {
                    amount = double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  
                  if (amount > _currentBalance) {
                    return 'Insufficient balance';
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gasPriceController,
                decoration: const InputDecoration(
                  labelText: 'Gas Price (Gwei, optional)',
                  border: OutlineInputBorder(),
                  hintText: '20',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // Optional field
                  }
                  
                  double? gasPrice;
                  try {
                    gasPrice = double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  
                  if (gasPrice <= 0) {
                    return 'Gas price must be greater than 0';
                  }
                  
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendTransaction,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('SEND'),
        ),
      ],
    );
  }
}
