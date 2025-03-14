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
import 'package:dadi/models/user_role.dart';
import 'package:dadi/providers/user_role_provider.dart';
import 'package:dadi/screens/role_selection_screen.dart';
import 'package:dadi/screens/creator_dashboard_screen.dart';
import 'package:dadi/screens/user_auction_browse_screen.dart';
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
      home: const RoleBasedHomeScreen(),
    );
  }
}

/// Widget that decides which screen to show based on user role
class RoleBasedHomeScreen extends StatelessWidget {
  const RoleBasedHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final web3Service = Provider.of<Web3Service>(context);
    final roleProvider = Provider.of<UserRoleProvider>(context);
    
    // If wallet is not connected, show the original home screen
    if (!web3Service.isConnected) {
      return const HomeScreenNew();
    }
    
    // If the user hasn't selected a role yet, show the role selection screen
    if (!roleProvider.hasSelectedRole) {
      return const RoleSelectionScreen();
    }
    
    // Show different screens based on role
    switch (roleProvider.role) {
      case UserRole.creator:
        return const CreatorDashboardScreen();
      case UserRole.user:
        return const UserAuctionBrowseScreen();
      default:
        return const HomeScreenNew();
    }
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
  
  // Enable mock mode for testing
  web3Service.isMockMode = true;
  
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
  
  // Create user role provider
  final userRoleProvider = UserRoleProvider();
  
  // Force mock mode for web platform
  if (kIsWeb) {
    developer.log('Web platform detected, forcing mock mode');
    // The web3Service is already set to mock mode
    developer.log('Mock mode already enabled for web platform');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Web3Service>.value(value: web3Service),
        ChangeNotifierProvider<MockButtplugService>(create: (context) => mockButtplugService),
        ChangeNotifierProvider<MetaTransactionProvider>(create: (context) => metaTransactionProvider),
        ChangeNotifierProvider<WalletServiceInterface>(create: (context) => walletService),
        ChangeNotifierProvider<UserRoleProvider>.value(value: userRoleProvider),
        if (kIsWeb) ChangeNotifierProvider<MockAuctionProvider>(create: (context) => MockAuctionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
