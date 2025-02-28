import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMetaMaskAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkMetaMask();
  }

  Future<void> _checkMetaMask() async {
    final web3Service = Provider.of<Web3Service>(context, listen: false);
    final isAvailable = await web3Service.isMetaMaskAvailable();
    setState(() {
      _isMetaMaskAvailable = isAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final web3Service = Provider.of<Web3Service>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blockchain Connection Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // MetaMask Status
            if (!_isMetaMaskAvailable && !web3Service.isMockMode)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MetaMask Not Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please install MetaMask extension and refresh the page to use real blockchain features.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            
            if (!_isMetaMaskAvailable && !web3Service.isMockMode)
              const SizedBox(height: 16),
            
            // Mock Mode Toggle
            SwitchListTile(
              title: const Text('Mock Mode'),
              subtitle: Text(
                web3Service.isMockMode
                    ? 'Using simulated blockchain data for testing'
                    : 'Using real blockchain connection',
                style: TextStyle(
                  color: web3Service.isMockMode ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: web3Service.isMockMode,
              onChanged: (value) async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Toggling mock mode...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                try {
                  await web3Service.toggleMockMode();
                  
                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        web3Service.isMockMode
                            ? 'Mock mode enabled - using simulated data'
                            : 'Mock mode disabled - using real blockchain',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error toggling mock mode: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            
            const Divider(),
            
            // Connection Status
            ListTile(
              title: const Text('Connection Status'),
              subtitle: Text(
                web3Service.isConnected 
                    ? web3Service.isMockMode
                        ? 'Connected to simulated blockchain'
                        : 'Connected to real blockchain'
                    : 'Not connected to blockchain',
              ),
              trailing: Icon(
                web3Service.isConnected 
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: web3Service.isConnected 
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            
            // Wallet Address
            if (web3Service.currentAddress != null)
              ListTile(
                title: const Text('Wallet Address'),
                subtitle: Text(
                  web3Service.currentAddress!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.account_balance_wallet),
              ),
            
            // Contract Status
            ListTile(
              title: const Text('Contract Status'),
              subtitle: Text(
                web3Service.isContractInitialized 
                    ? web3Service.isMockMode
                        ? 'Using mock contract'
                        : 'Contract initialized'
                    : 'Contract not initialized',
              ),
              trailing: Icon(
                web3Service.isContractInitialized 
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: web3Service.isContractInitialized 
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Connect/Disconnect Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: web3Service.isConnected ? Colors.red : Colors.green,
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  if (web3Service.isConnected) {
                    web3Service.disconnect();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Disconnected from blockchain'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Show loading indicator
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Connecting to blockchain...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    await web3Service.connect();
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          web3Service.isMockMode
                              ? 'Connected to simulated blockchain'
                              : 'Connected to real blockchain'
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  // Show detailed error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Connection error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: Text(
                web3Service.isConnected
                    ? 'Disconnect from Blockchain'
                    : 'Connect to Blockchain',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Contract Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: web3Service.isConnected
                ? () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    // Show loading indicator
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Testing contract...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    try {
                      await web3Service.testContract();
                      
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Contract test successful'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Contract test failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                : null, // Disable button if not connected
              child: const Text(
                'Test Contract Connection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
