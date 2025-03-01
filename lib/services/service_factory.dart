import 'package:flutter/foundation.dart';
import '../contracts/meta_transaction_relayer.dart';
import 'wallet_service_interface.dart';
import 'wallet_service_web.dart';
import 'wallet_service_mobile.dart';
import 'meta_transaction_service.dart';
import 'auction_service_meta.dart';
import 'transaction_websocket_service.dart';

/// Factory for creating service instances
/// This centralizes service creation and configuration
class ServiceFactory {
  /// Create a wallet service based on platform
  static WalletServiceInterface createWalletService({String? rpcUrl}) {
    final defaultRpcUrl = 'https://api.avax.network/ext/bc/C/rpc';
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
  }) {
    // Create WebSocket service if URL is provided
    TransactionWebSocketService? webSocketService;
    if (webSocketUrl != null) {
      webSocketService = TransactionWebSocketService(
        webSocketUrl: webSocketUrl,
        reconnectIntervalMs: 5000,
        maxReconnectAttempts: 10,
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
  }) {
    final walletService = createWalletService(rpcUrl: rpcUrl);
    
    final metaTransactionService = createMetaTransactionService(
      relayerUrl: relayerUrl,
      walletService: walletService,
      webSocketUrl: webSocketUrl,
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
    
    return {
      'walletService': walletService,
      'metaTransactionService': metaTransactionService,
      'relayer': relayer,
      'auctionService': auctionService,
    };
  }
}
