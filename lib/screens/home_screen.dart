import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import 'auction_screen.dart';
import 'auction_list_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final web3 = Provider.of<Web3Service>(context);
    final buttplug = Provider.of<MockButtplugService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DADI'),
        actions: [
          // Connect wallet button
          IconButton(
            icon: Icon(web3.isConnected ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined),
            onPressed: () => web3.isConnected ? web3.disconnect() : web3.connect(),
            tooltip: web3.isConnected ? 'Disconnect Wallet' : 'Connect Wallet',
          ),
          IconButton(
            icon: Icon(buttplug.isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
            onPressed: () => buttplug.isConnected ? buttplug.disconnect() : buttplug.connect(),
            tooltip: buttplug.isConnected ? 'Disconnect Device' : 'Connect Device',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!web3.isConnected)
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome to DADI',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Connect your wallet and device to get started',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                if (!web3.isConnected) ...[
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Connect Wallet'),
                    onPressed: web3.connect,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Connect Device'),
                    onPressed: buttplug.connect,
                  ),
                ],
                if (web3.isConnected) ...[
                  // Wallet management section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Wallet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Manage'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const WalletScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (web3.isConnected && buttplug.isConnected) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Auction'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AuctionScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Text('Browse Auctions'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AuctionListScreen(),
                      ),
                    ),
                  ),
                  // Debug button for contract initialization
                  const SizedBox(height: 32),
                  const Divider(),
                  const Text('Debug Options', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text(
                    'Contract Status: ${web3.isContractInitialized ? "Initialized" : "Not Initialized"}',
                    style: TextStyle(
                      color: web3.isContractInitialized ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mock Mode: ${web3.isMockMode ? "Enabled" : "Disabled"}',
                    style: TextStyle(
                      color: web3.isMockMode ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.build),
                    label: const Text('Initialize Contract'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      try {
                        await web3.initializeContract();
                        bool isValid = await web3.testContract();
                        
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            isValid ? 'Contract initialized and tested successfully' : 'Contract initialized but test failed',
                            isValid ? Colors.green : Colors.orange
                          );
                        }
                        
                        if (isValid) {
                          await web3.loadActiveAuctions();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showSnackBar(context, 'Error: $e', Colors.red);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Test Contract'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        bool isValid = await web3.testContract();
                        
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            isValid ? 'Contract test successful' : 'Contract test failed',
                            isValid ? Colors.green : Colors.red
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showSnackBar(context, 'Error: $e', Colors.red);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(web3.isMockMode ? Icons.toggle_on : Icons.toggle_off),
                    label: Text(web3.isMockMode ? 'Disable Mock Mode' : 'Enable Mock Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: web3.isMockMode ? Colors.orange : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      web3.toggleMockMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            web3.isMockMode 
                              ? 'Mock mode enabled' 
                              : 'Mock mode disabled'
                          ),
                          backgroundColor: web3.isMockMode ? Colors.orange : Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // Home is selected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Auctions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            // Already on home
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WalletScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AuctionListScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }
}
