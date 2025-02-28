import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/web3_service.dart';
import 'services/mock_buttplug_service.dart';
import 'screens/home_screen.dart';
import 'dart:developer' as developer;

// Helper function for logging
void _log(String message, {Object? error}) {
  final logMessage = 'Main: $message';
  
  // Log to developer console
  if (error != null) {
    developer.log(logMessage, name: 'Main', error: error);
    // Log errors to developer console
    developer.log('ERROR: $logMessage - ${error.toString()}', name: 'Main');
  } else {
    developer.log(logMessage, name: 'Main');
  }
}

void main() async {
  // Initialize logging
  _log('Starting DADI application...');

  // Initialize Web3Service
  final web3Service = Web3Service();
  
  // Check Ethereum provider status
  _log('Checking Ethereum provider status...');
  await web3Service.logEthereumProviderStatus();
  
  // Try to connect to the real blockchain
  _log('Attempting to connect to real blockchain...');
  await web3Service.connect().then((success) async {
    if (success) {
      _log('Successfully connected to blockchain');
      
      // Check contract initialization
      if (web3Service.isContractInitialized) {
        _log('Contract is initialized');
      } else {
        _log('Contract is not initialized');
      }
    } else {
      _log('Failed to connect with MetaMask, trying direct JsonRpc connection');
      
      // Try connecting with JsonRpcProvider directly
      await web3Service.connectWithJsonRpc().then((jsonRpcSuccess) async {
        if (jsonRpcSuccess) {
          _log('Successfully connected with JsonRpcProvider');
        } else {
          _log('Failed to connect with JsonRpcProvider, falling back to mock mode');
          // If we're not already in mock mode, toggle to mock mode
          if (!web3Service.isMockMode) {
            _log('Setting mock mode to true');
            web3Service.isMockMode = true;
          }
        }
      }).catchError((jsonRpcError) {
        _log('Error connecting with JsonRpcProvider:', error: jsonRpcError);
        // Fall back to mock mode
        if (!web3Service.isMockMode) {
          _log('Setting mock mode to true due to JsonRpc error');
          web3Service.isMockMode = true;
        }
      });
    }
  }).catchError((error) {
    _log('Error connecting to blockchain:', error: error);
    
    // Try connecting with JsonRpcProvider directly
    _log('Trying direct JsonRpc connection after error');
    web3Service.connectWithJsonRpc().then((jsonRpcSuccess) {
      if (jsonRpcSuccess) {
        _log('Successfully connected with JsonRpcProvider after error');
      } else {
        _log('Failed to connect with JsonRpcProvider, falling back to mock mode');
        // Fall back to mock mode
        if (!web3Service.isMockMode) {
          _log('Setting mock mode to true due to failed JsonRpc connection');
          web3Service.isMockMode = true;
        }
      }
    }).catchError((jsonRpcError) {
      _log('Error connecting with JsonRpcProvider:', error: jsonRpcError);
      // Fall back to mock mode
      if (!web3Service.isMockMode) {
        _log('Setting mock mode to true due to JsonRpc error');
        web3Service.isMockMode = true;
      }
    });
  });
  
  runApp(MyApp(web3Service: web3Service));
}

class MyApp extends StatelessWidget {
  final Web3Service web3Service;
  
  const MyApp({super.key, required this.web3Service});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: web3Service),
        ChangeNotifierProvider(create: (_) => MockButtplugService()),
      ],
      child: MaterialApp(
        title: 'DADI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
