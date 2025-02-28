import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';
import '../services/wallet_service_factory.dart';
import '../widgets/wallet_create_widget.dart';
import '../widgets/wallet_import_widget.dart';
import '../widgets/wallet_details_widget.dart';

/// Screen for wallet management
class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WalletServiceInterface _walletService;
  bool _isLoading = true;
  bool _walletExists = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _walletService = WalletServiceFactory.createWalletService();
    _checkWalletStatus();
  }

  Future<void> _checkWalletStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
      final exists = await walletService.walletExists();
      
      if (!mounted) return;
      
      setState(() {
        _walletExists = exists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking wallet status: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _walletService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DADI Wallet'),
          bottom: _walletExists
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Create Wallet'),
                    Tab(text: 'Import Wallet'),
                  ],
                ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_walletExists) {
      return const WalletDetailsWidget();
    } else {
      return TabBarView(
        controller: _tabController,
        children: [
          WalletCreateWidget(
            onWalletCreated: () {
              setState(() {
                _walletExists = true;
              });
            },
          ),
          WalletImportWidget(
            onWalletImported: () {
              setState(() {
                _walletExists = true;
              });
            },
          ),
        ],
      );
    }
  }
}
