import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../contracts/meta_transaction_relayer.dart';
import 'wallet_service_interface.dart';
import 'wallet_service_web.dart';
import 'wallet_service_mobile.dart';
import 'meta_transaction_service.dart';
import 'auction_service_meta.dart';
import 'transaction_websocket_service.dart';
import 'transaction_websocket_service_factory.dart';
import 'web3_service.dart';

/// Factory for creating service instances
/// This centralizes service creation and configuration
class ServiceFactory {
  /// Default relayer URL
  static const String defaultRelayerUrl = 'https://relayer.dadi.network';
  
  /// Default WebSocket URL
  static const String defaultWebSocketUrl = 'wss://relayer.dadi.network/ws';
  
  /// Create a wallet service based on platform
  static WalletServiceInterface createWalletService({String? rpcUrl}) {
    const defaultRpcUrl = 'https://api.avax.network/ext/bc/C/rpc';
    if (kIsWeb) {
      return WalletServiceWeb(
        rpcUrl: rpcUrl ?? defaultRpcUrl,
      );
    } else {
      return WalletServiceMobile(
        rpcUrl: rpcUrl ?? defaultRpcUrl,
      );
    }
  }
  
  /// Create a meta-transaction service with WebSocket support
  static MetaTransactionService createMetaTransactionService({
    required String relayerUrl,
    required WalletServiceInterface walletService,
    String? webSocketUrl,
    bool useMockWebSocket = kDebugMode, // Use mock mode in debug builds by default
  }) {
    // Create WebSocket service if URL is provided
    TransactionWebSocketService? webSocketService;
    if (webSocketUrl != null) {
      webSocketService = TransactionWebSocketServiceFactory.create(
        webSocketUrl: webSocketUrl,
        useMockMode: useMockWebSocket,
      );
    }
    
    return MetaTransactionService(
      relayerUrl: relayerUrl,
      walletService: walletService,
      webSocketService: webSocketService,
    );
  }
  
  /// Create a meta-transaction relayer
  static MetaTransactionRelayer createMetaTransactionRelayer({
    required MetaTransactionService metaTransactionService,
    required String relayerContractAddress,
  }) {
    return MetaTransactionRelayer(
      metaTransactionService: metaTransactionService,
      relayerContractAddress: relayerContractAddress,
    );
  }
  
  /// Create an auction service with meta-transaction support
  static AuctionServiceMeta createAuctionServiceMeta({
    required MetaTransactionRelayer relayer,
    required WalletServiceInterface walletService,
    required String auctionContractAddress,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
  }) {
    return AuctionServiceMeta(
      relayer: relayer,
      walletService: walletService,
      auctionContractAddress: auctionContractAddress,
      domainName: domainName,
      domainVersion: domainVersion,
      typeName: typeName,
      typeSuffixData: typeSuffixData,
      trustedForwarderAddress: trustedForwarderAddress,
    );
  }
  
  /// Create a Web3Service instance
  static Web3Service createWeb3Service({
    String? rpcUrl,
    String? auctionContractAddress,
  }) {
    developer.log('ServiceFactory: Creating Web3Service');
    final web3Service = Web3Service();
    
    // Force mock mode for web platform
    if (kIsWeb) {
      developer.log('ServiceFactory: Web platform detected, will use mock mode for Web3Service');
      web3Service.isMockMode = true;
    }
    
    return web3Service;
  }
  
  /// Create all services for the application
  static Map<String, dynamic> createAllServices({
    required String relayerUrl,
    required String webSocketUrl,
    required String relayerContractAddress,
    required String auctionContractAddress,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
    String? rpcUrl,
    bool useMockWebSocket = kDebugMode,
  }) {
    final walletService = createWalletService(rpcUrl: rpcUrl);
    
    final metaTransactionService = createMetaTransactionService(
      relayerUrl: relayerUrl,
      walletService: walletService,
      webSocketUrl: webSocketUrl,
      useMockWebSocket: useMockWebSocket,
    );
    
    final relayer = createMetaTransactionRelayer(
      metaTransactionService: metaTransactionService,
      relayerContractAddress: relayerContractAddress,
    );
    
    final auctionService = createAuctionServiceMeta(
      relayer: relayer,
      walletService: walletService,
      auctionContractAddress: auctionContractAddress,
      domainName: domainName,
      domainVersion: domainVersion,
      typeName: typeName,
      typeSuffixData: typeSuffixData,
      trustedForwarderAddress: trustedForwarderAddress,
    );
    
    // Create Web3Service
    final web3Service = createWeb3Service(
      rpcUrl: rpcUrl,
      auctionContractAddress: auctionContractAddress,
    );
    
    return {
      'walletService': walletService,
      'metaTransactionService': metaTransactionService,
      'relayer': relayer,
      'auctionService': auctionService,
      'web3Service': web3Service,
    };
  }
}
