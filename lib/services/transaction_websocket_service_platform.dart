// This file handles platform-specific implementations
// of the TransactionWebSocketService

import 'package:dadi/services/transaction_websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Import platform-specific implementations
import 'transaction_websocket_service_web.dart' if (dart.library.io) 'transaction_websocket_service_io.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Creates the appropriate platform-specific implementation of TransactionWebSocketService
TransactionWebSocketService createTransactionWebSocketService({
  required String webSocketUrl,
  int reconnectIntervalMs = 5000,
  int maxReconnectAttempts = 10,
  WebSocketChannelFactory? webSocketChannelFactory,
}) {
  // Default WebSocketChannelFactory if not provided
  final effectiveWebSocketChannelFactory = 
      webSocketChannelFactory ?? ((Uri url) => WebSocketChannel.connect(url));
      
  // Use the platform-specific implementation
  return createWebSocketService(
    webSocketUrl: webSocketUrl,
    reconnectIntervalMs: reconnectIntervalMs,
    maxReconnectAttempts: maxReconnectAttempts,
    webSocketChannelFactory: effectiveWebSocketChannelFactory,
  );
}
