// Stub implementation for non-web platforms
import 'package:dadi/services/transaction_websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Stub implementation of the web-specific TransactionWebSocketService
/// This is only used for conditional imports and should never be instantiated
class TransactionWebSocketServiceWeb extends TransactionWebSocketService {
  /// Constructor
  TransactionWebSocketServiceWeb({
    required String webSocketUrl,
    int reconnectIntervalMs = 2000,
    int maxReconnectAttempts = 15,
    int pingIntervalMs = 30000,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) : super(
         webSocketUrl: webSocketUrl,
         reconnectIntervalMs: reconnectIntervalMs,
         maxReconnectAttempts: maxReconnectAttempts,
         webSocketChannelFactory: webSocketChannelFactory ?? 
             ((Uri url) => WebSocketChannel.connect(url)),
       );

  /// Test helper method
  void testHandleMessage(dynamic message) {
    // Stub implementation
  }

  /// Test helper method
  void testTriggerReconnect() {
    // Stub implementation
  }
}
