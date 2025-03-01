import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meta_transaction_provider.dart';
import '../widgets/meta_transaction_history.dart';
import '../widgets/meta_transaction_quota.dart';
import '../services/meta_transaction_service.dart';
import '../contracts/meta_transaction_relayer.dart';
import '../services/wallet_service_interface.dart';

/// Screen for managing and viewing meta-transactions
class MetaTransactionScreen extends StatelessWidget {
  /// Route name for navigation
  static const routeName = '/meta-transactions';

  /// Constructor
  const MetaTransactionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get wallet service from provider
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    
    // Avalanche-specific configuration
    const domainName = "DADI Auction";
    const domainVersion = "1";
    const typeName = "my type name";
    const typeSuffixData = "bytes8 typeSuffixDatadatadatada)";
    const trustedForwarderAddress = "0x52C84043CD9c865236f11d9Fc9F56aa003c1f922";
    
    // Create meta-transaction service
    final metaTransactionService = MetaTransactionService(
      relayerUrl: 'https://relayer.dadi.network/relay',
      walletService: walletService,
    );
    
    // Create relayer
    final relayer = MetaTransactionRelayer(
      metaTransactionService: metaTransactionService,
      relayerContractAddress: '0x52C84043CD9c865236f11d9Fc9F56aa003c1f922', // Avalanche trusted forwarder
    );
    
    return ChangeNotifierProvider(
      create: (_) => MetaTransactionProvider(
        metaTransactionService: metaTransactionService,
        relayer: relayer,
        domainName: domainName,
        domainVersion: domainVersion,
        typeName: typeName,
        typeSuffixData: typeSuffixData,
        trustedForwarderAddress: trustedForwarderAddress,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gasless Transactions'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
            ),
          ],
        ),
        body: const Column(
          children: [
            MetaTransactionQuota(),
            Divider(),
            Expanded(
              child: MetaTransactionHistory(),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Show a help dialog explaining meta-transactions
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Gasless Transactions'),
        content: const SingleChildScrollView(
          child: Text(
            'Gasless transactions allow you to interact with blockchain contracts without paying gas fees. '
            'This is made possible by a relayer service that pays the gas fees on your behalf.\n\n'
            'Benefits:\n'
            '• No need to hold AVAX for gas fees\n'
            '• Simplified user experience\n'
            '• Faster onboarding for new users\n\n'
            'Limitations:\n'
            '• Limited daily free transactions\n'
            '• Some complex operations may not be supported\n'
            '• Slightly longer confirmation times\n\n'
            'Your daily quota resets every 24 hours.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
