// This is a stub file for transaction_websocket_service_web to be used on non-web platforms
// It provides the minimum implementation needed for tests to compile

import 'package:dadi/services/transaction_websocket_service.dart';

/// Creates a WebSocket service for testing
/// This is a stub implementation for non-web platforms
dynamic createWebSocketService({
  required String webSocketUrl,
  int reconnectIntervalMs = 5000,
  int maxReconnectAttempts = 5,
  dynamic webSocketChannelFactory,
}) {
  // Return a stub implementation that does nothing
  return StubWebSocketService(
    webSocketUrl: webSocketUrl,
    reconnectIntervalMs: reconnectIntervalMs,
    maxReconnectAttempts: maxReconnectAttempts,
  );
}

/// Stub implementation of TransactionWebSocketService for non-web platforms
class StubWebSocketService extends TransactionWebSocketService {
  /// Constructor
  StubWebSocketService({
    required String webSocketUrl,
    int reconnectIntervalMs = 5000,
    int maxReconnectAttempts = 5,
  }) : super(
         webSocketUrl: webSocketUrl,
         reconnectIntervalMs: reconnectIntervalMs,
         maxReconnectAttempts: maxReconnectAttempts,
         webSocketChannelFactory: null,
       );
  
  /// Stub method for testing
  void testHandleMessage(dynamic message) {
    // Do nothing in the stub
  }
  
  /// Stub method for testing
  void testTriggerReconnect() {
    // Do nothing in the stub
  }
}
