// Stub implementation for non-web platforms
import 'package:dadi/services/transaction_websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Stub implementation of the web-specific TransactionWebSocketService
/// This is only used for conditional imports and should never be instantiated
class TransactionWebSocketServiceWeb extends TransactionWebSocketService {
  /// Constructor
  TransactionWebSocketServiceWeb({
    required String webSocketUrl,
    int pingIntervalMs = 30000,
    WebSocketChannelFactory? webSocketChannelFactory,
    bool useMockMode = false,
  }) : super(
         webSocketUrl: webSocketUrl,
         webSocketChannelFactory: webSocketChannelFactory ?? 
             ((Uri url) => WebSocketChannel.connect(url)),
         useMockMode: useMockMode,
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

/// Factory function to create a web-specific WebSocket service
TransactionWebSocketService createWebSocketService({
  required String webSocketUrl,
  required WebSocketChannelFactory webSocketChannelFactory,
  bool useMockMode = false,
}) {
  if (useMockMode) {
    debugPrint('Creating mock WebSocket service for non-web platform');
  } else {
    debugPrint('Creating regular WebSocket service for non-web platform');
  }
  
  return TransactionWebSocketService(
    webSocketUrl: webSocketUrl,
    webSocketChannelFactory: webSocketChannelFactory,
    useMockMode: useMockMode,
  );
}
