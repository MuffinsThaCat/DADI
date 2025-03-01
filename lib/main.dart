import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:dadi/services/mock_buttplug_service.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'package:dadi/services/service_factory.dart';
import 'package:dadi/services/web3_service.dart';
import 'package:dadi/providers/meta_transaction_provider.dart';
import 'package:dadi/providers/mock_auction_provider.dart';
import 'package:dadi/screens/home_screen_new.dart';
import 'dart:developer' as developer;
import 'package:dadi/theme/app_theme.dart';

// Helper function for logging
void _log(String message, {Object? error}) {
  developer.log('DADI App: $message', error: error);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DADI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreenNew(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging
  _log('Starting DADI application...');
  
  // Create services
  final mockButtplugService = MockButtplugService();
  
  // Constants for service configuration
  const relayerUrl = 'https://relayer.dadi.network';
  const webSocketUrl = 'wss://relayer.dadi.network/ws';
  const trustedForwarderAddress = '0x52C84043CD9c865236f11d9Fc9F56aa003c1f922';
  const auctionContractAddress = '0x1234567890123456789012345678901234567890';
  const domainName = 'DADI Auction';
  const domainVersion = '1';
  const typeName = 'my type name';
  const typeSuffixData = 'bytes8 typeSuffixDatadatadatada)';
  
  // Create services using static factory methods
  final walletService = ServiceFactory.createWalletService();
  
  // Create meta transaction service
  final metaTransactionService = ServiceFactory.createMetaTransactionService(
    relayerUrl: relayerUrl,
    walletService: walletService,
    webSocketUrl: webSocketUrl,
    useMockWebSocket: kDebugMode,
  );
  
  // Create meta transaction relayer
  final metaTransactionRelayer = ServiceFactory.createMetaTransactionRelayer(
    metaTransactionService: metaTransactionService,
    relayerContractAddress: trustedForwarderAddress,
  );
  
  // Create Web3Service
  final web3Service = await ServiceFactory.createAllServices(
    relayerUrl: relayerUrl,
    webSocketUrl: webSocketUrl,
    relayerContractAddress: trustedForwarderAddress,
    auctionContractAddress: auctionContractAddress,
    domainName: domainName,
    domainVersion: domainVersion,
    typeName: typeName,
    typeSuffixData: typeSuffixData,
    trustedForwarderAddress: trustedForwarderAddress,
  )['web3Service'];
  
  // Create providers
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
  
  // Force mock mode for web platform
  if (kIsWeb) {
    developer.log('Web platform detected, forcing mock mode');
    // The web3Service is already set to mock mode in the service factory
    // No need to call forceEnableMockMode() here as it's already handled
    developer.log('Mock mode already enabled for web platform');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Web3Service>.value(value: web3Service),
        ChangeNotifierProvider<MockButtplugService>(create: (context) => mockButtplugService),
        ChangeNotifierProvider<MetaTransactionProvider>(create: (context) => metaTransactionProvider),
        Provider<WalletServiceInterface>(create: (context) => walletService),
        if (kIsWeb) ChangeNotifierProvider<MockAuctionProvider>(create: (context) => MockAuctionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
