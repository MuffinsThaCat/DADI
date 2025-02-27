import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
            const Text(
              'Blockchain Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mock Mode Toggle
            SwitchListTile(
              title: const Text('Mock Mode'),
              subtitle: const Text(
                'Enable to use simulated blockchain data for testing',
              ),
              value: web3Service.isMockMode,
              onChanged: (value) {
                web3Service.toggleMockMode();
              },
            ),
            
            const Divider(),
            
            // Connection Status
            ListTile(
              title: const Text('Connection Status'),
              subtitle: Text(
                web3Service.isConnected 
                    ? 'Connected to blockchain'
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
            
            // Contract Status
            ListTile(
              title: const Text('Contract Status'),
              subtitle: Text(
                web3Service.isContractInitialized 
                    ? 'Contract initialized'
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
              onPressed: web3Service.isConnected
                  ? web3Service.disconnect
                  : web3Service.connect,
              child: Text(
                web3Service.isConnected
                    ? 'Disconnect from Blockchain'
                    : 'Connect to Blockchain',
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Test Contract Button
            ElevatedButton(
              onPressed: () async {
                final success = await web3Service.testContract();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Contract test successful'
                          : 'Contract test failed',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Test Contract'),
            ),
          ],
        ),
      ),
    );
  }
}
