// Implementation for non-web platforms (IO)
import 'package:dadi/services/transaction_websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'transaction_websocket_service_platform.dart';

/// IO-specific implementation of TransactionWebSocketService
/// This is used for mobile and desktop platforms
class TransactionWebSocketServiceIO extends TransactionWebSocketService {
  /// Constructor
  TransactionWebSocketServiceIO({
    required String webSocketUrl,
    WebSocketChannel Function(Uri)? webSocketChannelFactory,
  }) : super(
         webSocketUrl: webSocketUrl,
         webSocketChannelFactory: webSocketChannelFactory ?? 
             ((Uri url) => WebSocketChannel.connect(url)),
       );
       
  /// For testing: Process a WebSocket message directly
  void testHandleMessage(dynamic message) {
    handleWebSocketMessage(message);
  }
  
  /// For testing: Callback to track connection attempts
  Function? testConnectionAttemptCallback;
  
  /// For testing: Manually trigger a reconnection
  void testTriggerReconnect() {
    scheduleReconnect();
  }
}

/// Creates a non-web specific WebSocket service
/// This function is used for testing and by the service factory
TransactionWebSocketServiceIO createWebSocketService({
  required String webSocketUrl,
  int reconnectIntervalMs = 5000,
  int maxReconnectAttempts = 5,
  WebSocketChannelFactory? webSocketChannelFactory,
  bool useMockMode = false,
}) {
  return TransactionWebSocketServiceIO(
    webSocketUrl: webSocketUrl,
    webSocketChannelFactory: webSocketChannelFactory,
  );
}
