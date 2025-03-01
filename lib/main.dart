import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/web3_service.dart';
import 'services/mock_buttplug_service.dart';
import 'services/wallet_service_interface.dart';
import 'services/service_factory.dart';
import 'services/meta_transaction_service.dart';
import 'contracts/meta_transaction_relayer.dart';
import 'providers/meta_transaction_provider.dart';
import 'screens/home_screen_new.dart';
import 'screens/meta_transaction_screen.dart';
import 'dart:developer' as developer;
import 'theme/app_theme.dart';

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
  
  // Avalanche configuration
  const relayerUrl = 'https://relayer.dadi.network'; // Replace with actual Avalanche relayer URL
  const webSocketUrl = 'wss://relayer.dadi.network/ws'; // WebSocket URL for transaction status updates
  const trustedForwarderAddress = '0x52C84043CD9c865236f11d9Fc9F56aa003c1f922'; // Replace with actual deployed address
  const auctionContractAddress = '0x1234567890123456789012345678901234567890'; // Replace with actual deployed address
  const domainName = 'DADI Auction'; // Domain name registered with the forwarder
  const domainVersion = '1'; // Domain version registered with the forwarder
  const typeName = 'my type name'; // Type name registered with the forwarder
  const typeSuffixData = 'bytes8 typeSuffixDatadatadatada)'; // Type suffix registered with the forwarder
  
  // Create all services using the factory
  final services = ServiceFactory.createAllServices(
    relayerUrl: relayerUrl,
    webSocketUrl: webSocketUrl,
    relayerContractAddress: trustedForwarderAddress,
    auctionContractAddress: auctionContractAddress,
    domainName: domainName,
    domainVersion: domainVersion,
    typeName: typeName,
    typeSuffixData: typeSuffixData,
    trustedForwarderAddress: trustedForwarderAddress,
  );
  
  final walletService = services['walletService'] as WalletServiceInterface;
  final metaTransactionService = services['metaTransactionService'] as MetaTransactionService;
  final metaTransactionRelayer = services['relayer'] as MetaTransactionRelayer;
  
  _log('Wallet service initialized');
  _log('Meta-transaction services initialized for Avalanche with WebSocket support');
  
  // Initialize Meta-Transaction Provider with Avalanche parameters
  final metaTransactionProvider = MetaTransactionProvider(
    metaTransactionService: metaTransactionService,
    relayer: metaTransactionRelayer,
    domainName: domainName,
    domainVersion: domainVersion,
    typeName: typeName,
    typeSuffixData: typeSuffixData,
    trustedForwarderAddress: trustedForwarderAddress,
    webSocketService: metaTransactionService.webSocketService,
  );
  
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
        _log('Setting mock mode to true due to error');
        web3Service.isMockMode = true;
      });
    }
  }).catchError((error) {
    _log('Error connecting to blockchain:', error: error);
    // Fall back to mock mode
    _log('Setting mock mode to true due to error');
    web3Service.isMockMode = true;
  });
  
  // Initialize the MockButtplugService
  final mockButtplugService = MockButtplugService();
  
  // Run the app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => web3Service),
        ChangeNotifierProvider(create: (context) => mockButtplugService),
        ChangeNotifierProvider(create: (context) => metaTransactionProvider),
        Provider<WalletServiceInterface>(create: (context) => walletService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DADI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreenNew(),
        '/meta-transaction': (context) => const MetaTransactionScreen(),
      },
    );
  }
}
