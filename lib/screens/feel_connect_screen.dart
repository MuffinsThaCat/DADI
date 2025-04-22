import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feel_technology_service.dart';

/// Screen for connecting to Feel Technology devices via QR code
class FeelConnectScreen extends StatefulWidget {
  const FeelConnectScreen({Key? key}) : super(key: key);

  @override
  State<FeelConnectScreen> createState() => _FeelConnectScreenState();
}

class _FeelConnectScreenState extends State<FeelConnectScreen> {
  bool _isConnecting = false;
  String _statusMessage = 'Ready to connect';
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateConnection();
    });
  }

  void _initiateConnection() async {
    final feelService = Provider.of<FeelTechnologyService>(context, listen: false);
    
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Initiating connection...';
    });
    
    try {
      await feelService.connect();
      
      // Start checking connection status
      _connectionCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (feelService.isConnected) {
          setState(() {
            _statusMessage = 'Connected to ${feelService.currentDevice}';
          });
          _connectionCheckTimer?.cancel();
          
          // Return to previous screen after successful connection
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && feelService.isConnected) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feelService = Provider.of<FeelTechnologyService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                'Scan the QR Code with the FeelConnect App',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // This is a placeholder - the actual QR code will be shown by the Feel.js library
              // in a web overlay once connect() is called
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('QR Code will appear here'),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _statusMessage,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!feelService.isConnected) ...[
                ElevatedButton(
                  onPressed: _isConnecting ? null : _initiateConnection,
                  child: Text(_isConnecting ? 'Connecting...' : 'Try Again'),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connected!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Text(
                'Don\'t have the FeelConnect app?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // In a real implementation, this would open the app store or a download page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download FeelConnect from the App Store or Google Play'),
                    ),
                  );
                },
                child: const Text('Download it now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
