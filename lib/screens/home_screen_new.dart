import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import 'auction_list_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import '../widgets/wavy_background.dart';

class HomeScreenNew extends StatefulWidget {
  const HomeScreenNew({Key? key}) : super(key: key);

  @override
  State<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends State<HomeScreenNew> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const AuctionListScreen();
      case 1:
        return const WalletScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const AuctionListScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final web3 = Provider.of<Web3Service>(context);
    final buttplug = Provider.of<MockButtplugService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DADI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.primary,
        actions: [
          // Connect wallet button
          IconButton(
            icon: Icon(
              web3.isConnected 
                  ? Icons.account_balance_wallet 
                  : Icons.account_balance_wallet_outlined,
              color: web3.isConnected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: () => web3.isConnected ? web3.disconnect() : web3.connect(),
            tooltip: web3.isConnected ? 'Disconnect Wallet' : 'Connect Wallet',
          ),
          IconButton(
            icon: Icon(
              buttplug.isConnected 
                  ? Icons.bluetooth_connected 
                  : Icons.bluetooth,
              color: buttplug.isConnected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: () => buttplug.isConnected ? buttplug.disconnect() : buttplug.connect(),
            tooltip: buttplug.isConnected ? 'Disconnect Device' : 'Connect Device',
          ),
        ],
      ),
      body: WavyBackground(
        primaryColor: theme.colorScheme.primary,
        secondaryColor: theme.colorScheme.secondary,
        child: _buildCurrentScreen(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Auctions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
