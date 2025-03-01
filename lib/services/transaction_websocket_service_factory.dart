import 'package:web_socket_channel/web_socket_channel.dart';
import 'transaction_websocket_service.dart';
import 'transaction_websocket_service_platform.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Factory for creating TransactionWebSocketService instances
class TransactionWebSocketServiceFactory {
  /// Create a new TransactionWebSocketService
  static TransactionWebSocketService create({
    required String webSocketUrl,
    WebSocketChannelFactory? webSocketChannelFactory,
    bool useMockMode = false,
  }) {
    // Use the platform-specific implementation
    return createTransactionWebSocketService(
      webSocketUrl: webSocketUrl,
      webSocketChannelFactory: webSocketChannelFactory,
      useMockMode: useMockMode,
    );
  }
}
