import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../services/web3_service.dart';
import '../services/device_connector_factory.dart';
import '../services/device_connector_interface.dart';
import '../widgets/wavy_background.dart';

// Only import this on web to avoid errors on mobile
import '../services/device_connector_web.dart' if (dart.library.io) 'dart:ui' as web;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMetaMaskAvailable = false;
  late DeviceConnectorInterface _deviceConnector;

  @override
  void initState() {
    super.initState();
    _checkMetaMask();
    _deviceConnector = DeviceConnectorFactory.create();
    _deviceConnector.addListener(_updateDeviceState);
    
    // Register connection code display callback if on web
    if (kIsWeb) {
      web.DeviceConnectorWeb.onConnectionCodeRequested = _showFeelConnectCode;
    }
  }
  
  void _updateDeviceState() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  void dispose() {
    _deviceConnector.removeListener(_updateDeviceState);
    // Unregister callback if on web
    if (kIsWeb) {
      web.DeviceConnectorWeb.onConnectionCodeRequested = null;
    }
    super.dispose();
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: WavyBackground(
        primaryColor: theme.colorScheme.primary,
        secondaryColor: theme.colorScheme.secondary,
        child: Padding(
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
              
              const SizedBox(height: 24),
              
              // Device connection section
              const SizedBox(height: 32),
              Text(
                'Device Connection Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // FeelConnect pairing code card
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.bluetooth_connected,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'FeelConnect Pairing Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            'DADI_TEST_123',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: 'DADI_TEST_123'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pairing code copied to clipboard')),
                              );
                            },
                            tooltip: 'Copy to clipboard',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter this code in the FeelConnect app to pair your device',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Device status
              ListTile(
                title: const Text('Device Status'),
                subtitle: Text(
                  _deviceConnector.isConnected 
                      ? 'Connected to ${_deviceConnector.currentDevice}'
                      : 'No device connected',
                ),
                trailing: Icon(
                  _deviceConnector.isConnected 
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _deviceConnector.isConnected 
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),
              
              // Vibration level if connected
              if (_deviceConnector.isConnected)
                Slider(
                  value: _deviceConnector.currentVibration,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_deviceConnector.currentVibration * 100).toStringAsFixed(0)}%',
                  onChanged: (value) async {
                    try {
                      if (value > 0) {
                        await _deviceConnector.startVibration(value);
                      } else {
                        await _deviceConnector.stopVibration();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error controlling device: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              
              const SizedBox(height: 16),
              
              // Connection method options
              if (!_deviceConnector.isConnected)
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lovense Device Connection',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect directly to your Hush or other Lovense device using Web Bluetooth.'
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('Connect via Web Bluetooth'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            onPressed: kIsWeb ? () async {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Scanning for Lovense devices...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                
                                // Force Web Bluetooth strategy
                                if (kIsWeb && _deviceConnector is web.DeviceConnectorWeb) {
                                  (_deviceConnector as web.DeviceConnectorWeb).setConnectionStrategy(
                                    web.ConnectionStrategy.webBluetooth
                                  );
                                }
                                
                                await _deviceConnector.connect();
                                
                                if (_deviceConnector.isConnected) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Connected to ${_deviceConnector.currentDevice}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Connection error: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            } : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Note: Make sure your device is powered on and in pairing mode',
                            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Connection Status Card
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                color: _deviceConnector.isConnected ? Colors.green.shade50 : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _deviceConnector.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: _deviceConnector.isConnected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connection Status: ${_deviceConnector.isConnected ? "CONNECTED" : "DISCONNECTED"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _deviceConnector.isConnected ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (_deviceConnector.isConnected) ...[  
                        const SizedBox(height: 8),
                        Text(
                          'Connected to: ${_deviceConnector.currentDevice}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vibration: ${(_deviceConnector.currentVibration * 100).round()}%',
                          style: TextStyle(
                            color: _deviceConnector.currentVibration > 0 ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Connect/Disconnect Device Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: _deviceConnector.isConnected ? Colors.red : Colors.green,
                        ),
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          
                          try {
                            if (_deviceConnector.isConnected) {
                              await _deviceConnector.disconnect();
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Device disconnected'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              // Default auto connection approach
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Connecting to device...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              
                              await _deviceConnector.connect();
                              
                              // Add a small delay to ensure UI updates
                              await Future.delayed(const Duration(milliseconds: 500));
                              
                              if (_deviceConnector.isConnected) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Connected to ${_deviceConnector.currentDevice}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            // Show error
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Device connection error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        child: Text(
                          _deviceConnector.isConnected
                              ? 'Disconnect Device'
                              : 'Connect Device',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_deviceConnector.isConnected) ...[  
                        const SizedBox(height: 8),
                        const Text(
                          'Tip: Open browser console (F12) to see debug messages',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Test Vibration Button (Only visible when connected)
              if (_deviceConnector.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    elevation: 3,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connection Test',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connected to: ${_deviceConnector.currentDevice}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Connection verification:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '100% RELIABLE CONNECTION VERIFICATION:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.blue.shade50,
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('1. Use one of the test buttons below'),
                                Text('2. If your device vibrates → CONNECTION SUCCESSFUL ✓'),
                                Text('3. No vibration → Device not properly connected ✗'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.vibration),
                                label: const Text('Test Low'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade400,
                                ),
                                onPressed: () async {
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sending test vibration...'),
                                        duration: Duration(milliseconds: 500),
                                      ),
                                    );
                                    
                                    // Low intensity vibration (25%)
                                    await _deviceConnector.startVibration(0.25);
                                    
                                    // Stop after 1 second
                                    Future.delayed(const Duration(seconds: 1), () {
                                      _deviceConnector.stopVibration();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Low vibration test sent'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Test failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.vibration),
                                label: const Text('Test High'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                ),
                                onPressed: () async {
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sending test vibration...'),
                                        duration: Duration(milliseconds: 500),
                                      ),
                                    );
                                    
                                    // High intensity vibration (75%)
                                    await _deviceConnector.startVibration(0.75);
                                    
                                    // Stop after 1 second
                                    Future.delayed(const Duration(seconds: 1), () {
                                      _deviceConnector.stopVibration();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('High vibration test sent'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Test failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // QR code is now shown directly through showDialog
            ],
          ),
        ),
      ),
    );
  }
  
  void _showFeelConnectCode(String connectionCode) {
    // Use the provided connection code directly
        
    // Display the connection code in a dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Connect Your Device',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bluetooth_connected,
                  size: 48,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter this code in the FeelConnect app:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                // Connection code display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: SelectableText(
                    connectionCode,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Code'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: connectionCode));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  // The QR code dialog is now built directly in the _showFeelConnectQRCode method
}
