import 'dart:io';
import 'package:flutter/foundation.dart';
import 'wallet_service_interface.dart';
import 'wallet_service_mobile.dart';
import 'wallet_service_web.dart';
import 'transaction_websocket_service.dart';
import 'transaction_websocket_service_platform.dart' as platform;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Factory for creating the appropriate wallet service implementation
class WalletServiceFactory {
  /// Create a wallet service based on the current platform
  static WalletServiceInterface createWalletService({String? rpcUrl}) {
    // Default RPC URL if not provided
    const defaultRpcUrl = 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY';
    final effectiveRpcUrl = rpcUrl ?? defaultRpcUrl;
    
    if (kIsWeb) {
      // Web implementation
      return WalletServiceWeb(rpcUrl: effectiveRpcUrl);
    } else if (Platform.isIOS || Platform.isAndroid) {
      // Mobile implementation
      return WalletServiceMobile(rpcUrl: effectiveRpcUrl);
    } else {
      // Desktop implementation (fallback to mobile for now)
      return WalletServiceMobile(rpcUrl: effectiveRpcUrl);
    }
  }
  
  /// Create a transaction websocket service
  static TransactionWebSocketService createTransactionWebSocketService({
    String webSocketUrl = 'wss://relayer.dadi.network/ws',
    int reconnectIntervalMs = 5000,
    int maxReconnectAttempts = 10,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) {
    return platform.createTransactionWebSocketService(
      webSocketUrl: webSocketUrl,
      reconnectIntervalMs: reconnectIntervalMs,
      maxReconnectAttempts: maxReconnectAttempts,
      webSocketChannelFactory: webSocketChannelFactory,
    );
  }
  
  /// Create all services needed for the app
  static Map<String, dynamic> createAllServices({String? rpcUrl}) {
    final walletService = createWalletService(rpcUrl: rpcUrl);
    final webSocketService = createTransactionWebSocketService();
    
    return {
      'walletService': walletService,
      'webSocketService': webSocketService,
    };
  }
}
