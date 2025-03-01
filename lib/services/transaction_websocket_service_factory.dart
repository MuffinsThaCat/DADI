import 'package:web_socket_channel/web_socket_channel.dart';
import 'transaction_websocket_service.dart';
import 'transaction_websocket_service_platform.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Factory for creating the appropriate TransactionWebSocketService based on platform
class TransactionWebSocketServiceFactory {
  /// Create the appropriate WebSocket service for the current platform
  static TransactionWebSocketService create({
    required String webSocketUrl,
    int reconnectIntervalMs = 5000,
    int maxReconnectAttempts = 5,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) {
    // Use the platform-specific implementation
    return createTransactionWebSocketService(
      webSocketUrl: webSocketUrl,
      reconnectIntervalMs: reconnectIntervalMs,
      maxReconnectAttempts: maxReconnectAttempts,
      webSocketChannelFactory: webSocketChannelFactory,
    );
  }
}
