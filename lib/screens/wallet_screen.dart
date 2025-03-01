import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';
import '../services/wallet_service_factory.dart';
import '../widgets/wallet_create_widget.dart';
import '../widgets/wallet_import_widget.dart';
import '../widgets/wallet_details_widget.dart';
import '../widgets/wavy_background.dart';

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    } catch (e, stackTrace) {
      if (!mounted) return;
      
      debugPrint('Error checking wallet status: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
        // Default to false when there's an error
        _walletExists = false;
      });
      
      // Use a post-frame callback to show the SnackBar after the current frame
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final errorMessage = e.toString();
            final displayMessage = errorMessage.length > 100 
                ? '${errorMessage.substring(0, 100)}...' 
                : errorMessage;
                
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error checking wallet status: $displayMessage'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () {
                    _checkWalletStatus();
                  },
                ),
              ),
            );
          } catch (snackBarError) {
            // Ignore ScaffoldMessenger errors in tests
            debugPrint('Could not show SnackBar: $snackBarError');
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ChangeNotifierProvider.value(
      value: _walletService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'DADI Wallet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: _walletExists
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      key: Key('create'),
                      text: 'Create Wallet',
                      icon: Icon(Icons.add_circle_outline),
                    ),
                    Tab(
                      key: Key('import'),
                      text: 'Import Wallet',
                      icon: Icon(Icons.file_download_outlined),
                    ),
                  ],
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading wallet...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (_walletExists) {
      return const WalletDetailsWidget();
    } else {
      return WavyBackground(
        primaryColor: theme.colorScheme.primary,
        secondaryColor: theme.colorScheme.secondary,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface.withOpacity(0.8),
                theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ],
            ),
          ),
          child: TabBarView(
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
          ),
        ),
      );
    }
  }
}
