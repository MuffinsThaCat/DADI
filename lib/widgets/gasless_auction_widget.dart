import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meta_transaction_provider.dart';

/// Widget for interacting with auctions using gasless meta-transactions
class GaslessAuctionWidget extends StatefulWidget {
  final String deviceId;
  final double currentPrice;
  final bool isActive;
  final bool isOwner;
  
  const GaslessAuctionWidget({
    Key? key,
    required this.deviceId,
    required this.currentPrice,
    required this.isActive,
    required this.isOwner,
  }) : super(key: key);
  
  @override
  State<GaslessAuctionWidget> createState() => _GaslessAuctionWidgetState();
}

class _GaslessAuctionWidgetState extends State<GaslessAuctionWidget> {
  final TextEditingController _bidController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  @override
  void initState() {
    super.initState();
    // Set initial bid value to current price + 10%
    _bidController.text = (widget.currentPrice * 1.1).toStringAsFixed(4);
  }
  
  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }
  
  Future<void> _placeBid() async {
    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null || bidAmount <= widget.currentPrice) {
      setState(() {
        _errorMessage = 'Bid must be higher than current price';
        _successMessage = null;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final metaProvider = Provider.of<MetaTransactionProvider>(context, listen: false);
      
      // Execute the transaction via the provider
      final txHash = await metaProvider.executeFunction(
        targetContract: '0x0987654321098765432109876543210987654321', // Auction contract
        functionSignature: 'placeBid(bytes32,uint256)',
        functionParams: [
          widget.deviceId,
          (bidAmount * 1e18).toString(), // Convert to wei
        ],
        description: 'Bid ${bidAmount.toStringAsFixed(4)} ETH on ${widget.deviceId}',
      );
      
      setState(() {
        _successMessage = 'Bid placed successfully! Transaction: ${txHash.substring(0, 10)}...';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _finalizeAuction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final metaProvider = Provider.of<MetaTransactionProvider>(context, listen: false);
      
      // Execute the transaction via the provider
      final txHash = await metaProvider.executeFunction(
        targetContract: '0x0987654321098765432109876543210987654321', // Auction contract
        functionSignature: 'finalizeAuction(bytes32)',
        functionParams: [widget.deviceId],
        description: 'Finalize auction for ${widget.deviceId}',
      );
      
      setState(() {
        _successMessage = 'Auction finalized! Transaction: ${txHash.substring(0, 10)}...';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Get quota information from provider
    final metaProvider = Provider.of<MetaTransactionProvider>(context);
    final hasQuota = metaProvider.hasQuotaAvailable;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gasless Auction Interaction',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Device ID: ${widget.deviceId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Current Price: ${widget.currentPrice} ETH',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${widget.isActive ? "Active" : "Closed"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (widget.isActive && !widget.isOwner) ...[
              TextField(
                controller: _bidController,
                decoration: const InputDecoration(
                  labelText: 'Your Bid (ETH)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!hasQuota || _isLoading) ? null : _placeBid,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Place Gasless Bid'),
                ),
              ),
              if (!hasQuota && !_isLoading) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber.shade900, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daily gasless transaction quota exceeded. Please try again tomorrow or use a regular transaction.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'No gas fees required - powered by meta-transactions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/meta-transactions');
                },
                child: const Text('View Transaction History'),
              ),
            ],
            if (widget.isActive && widget.isOwner) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!hasQuota || _isLoading) ? null : _finalizeAuction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Finalize Auction (Gasless)'),
                ),
              ),
              if (!hasQuota && !_isLoading) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber.shade900, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daily gasless transaction quota exceeded. Please try again tomorrow or use a regular transaction.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.green.shade100,
                width: double.infinity,
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
