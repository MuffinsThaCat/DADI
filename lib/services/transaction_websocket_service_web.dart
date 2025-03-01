// ignore_for_file: implementation_imports, avoid_web_libraries_in_flutter
// This file intentionally uses web-only libraries (dart:html and web_socket_channel/html) 
// as it's specifically designed for the web platform implementation

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

/// Factory function type for creating WebSocket channels
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri);

/// Web-specific implementation of TransactionWebSocketService that handles
/// browser-specific behaviors like tab visibility changes and network status.
class TransactionWebSocketServiceImpl extends TransactionWebSocketService {
  /// Subscription for visibility change events
  StreamSubscription<html.Event>? _visibilityChangeSubscription;
  
  /// Subscription for online events
  StreamSubscription<html.Event>? _onlineStatusSubscription;
  
  /// Subscription for offline events
  StreamSubscription<html.Event>? _offlineStatusSubscription;
  
  /// Subscription for beforeunload events
  StreamSubscription<html.Event>? _beforeUnloadSubscription;
  
  /// Subscription for focus events
  StreamSubscription<html.Event>? _focusSubscription;
  
  /// Subscription for blur events
  StreamSubscription<html.Event>? _blurSubscription;
  
  /// Flag to track if tab was previously visible
  bool _wasVisible = true;
  
  /// Flag to track if tab is currently focused
  bool _isFocused = true;
  
  /// Timer for ping messages to keep connection alive
  Timer? _pingTimer;
  
  /// Interval for ping messages in milliseconds (default: 30 seconds)
  final int _pingIntervalMs;
  
  /// Constructor with web-specific defaults
  TransactionWebSocketServiceImpl({
    required String webSocketUrl,
    int reconnectIntervalMs = 2000, // Faster reconnect for web
    int maxReconnectAttempts = 15,  // More attempts for web
    int pingIntervalMs = 30000,     // 30 second ping interval
    WebSocketChannelFactory? webSocketChannelFactory,
  }) : _pingIntervalMs = pingIntervalMs,
       super(
         webSocketUrl: webSocketUrl,
         reconnectIntervalMs: reconnectIntervalMs,
         maxReconnectAttempts: maxReconnectAttempts,
         webSocketChannelFactory: webSocketChannelFactory ?? 
             ((Uri url) => HtmlWebSocketChannel.connect(url)),
       );
  
  @override
  Future<void> initialize() async {
    // Listen for visibility changes
    _visibilityChangeSubscription = html.document.onVisibilityChange.listen(_handleVisibilityChange);
    
    // Listen for online/offline events
    _onlineStatusSubscription = html.window.onOnline.listen(_handleOnline);
    _offlineStatusSubscription = html.window.onOffline.listen(_handleOffline);
    
    // Listen for tab/window focus events
    _focusSubscription = html.window.onFocus.listen(_handleFocus);
    _blurSubscription = html.window.onBlur.listen(_handleBlur);
    
    // Listen for page unload events
    _beforeUnloadSubscription = html.window.onBeforeUnload.listen(_handleBeforeUnload);
    
    // Start ping timer to keep connection alive
    _startPingTimer();
    
    // Initialize the service
    await super.initialize();
  }
  
  /// Start timer to send periodic ping messages
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(milliseconds: _pingIntervalMs), (_) {
      _sendPing();
    });
  }
  
  /// Send a ping message to keep the connection alive
  void _sendPing() {
    try {
      // Access the parent class's sendMessage method
      sendPingMessage({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error sending ping: $e');
    }
  }
  
  /// Helper method to send a message via the parent class
  void sendPingMessage(Map<String, dynamic> message) {
    // This is a workaround to access the protected _sendMessage method
    final channel = super.channel;
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('Error sending WebSocket message: $e');
      }
    }
  }
  
  /// Handle visibility change events
  void _handleVisibilityChange(html.Event event) {
    final isVisible = html.document.visibilityState == 'visible';
    
    // If visibility changed from hidden to visible, reconnect
    if (isVisible && !_wasVisible) {
      debugPrint('Tab became visible, reconnecting WebSocket');
      _reconnect();
    }
    
    _wasVisible = isVisible;
  }
  
  /// Handle online events
  void _handleOnline(html.Event event) {
    debugPrint('Browser went online, reconnecting WebSocket');
    _reconnect();
  }
  
  /// Handle offline events
  void _handleOffline(html.Event event) {
    debugPrint('Browser went offline, WebSocket will reconnect when online');
  }
  
  /// Handle focus events
  void _handleFocus(html.Event event) {
    _isFocused = true;
    debugPrint('Tab gained focus, reconnecting WebSocket if needed');
    
    // Only reconnect if we're focused to avoid unnecessary reconnections
    if (_isFocused) {
      _reconnect();
    }
  }
  
  /// Handle blur events
  void _handleBlur(html.Event event) {
    _isFocused = false;
    debugPrint('Tab lost focus');
  }
  
  /// Handle page unload events
  void _handleBeforeUnload(html.Event event) {
    // Clean up resources when page is unloaded
    dispose();
  }
  
  /// Reconnect the WebSocket
  void _reconnect() {
    scheduleReconnect();
  }
  
  @override
  Future<void> dispose() async {
    // Cancel all event subscriptions
    _visibilityChangeSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _offlineStatusSubscription?.cancel();
    _beforeUnloadSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    
    // Cancel ping timer
    _pingTimer?.cancel();
    
    // Call super to clean up base class resources
    await super.dispose();
  }
  
  /// For testing: Process a WebSocket message directly
  void testHandleMessage(dynamic message) {
    handleWebSocketMessage(message);
  }
  
  /// For testing: Manually trigger a reconnection
  void testTriggerReconnect() {
    _reconnect();
  }
  
  /// For testing: Callback to track connection attempts
  Function? testConnectionAttemptCallback;
}

// Conditional stub implementation for non-web platforms
class TransactionWebSocketServiceStub extends TransactionWebSocketService {
  /// Constructor
  TransactionWebSocketServiceStub({
    required String webSocketUrl,
    int reconnectIntervalMs = 5000,
    int maxReconnectAttempts = 10,
  }) : super(
         webSocketUrl: webSocketUrl,
         reconnectIntervalMs: reconnectIntervalMs,
         maxReconnectAttempts: maxReconnectAttempts,
         webSocketChannelFactory: (url) => throw UnsupportedError(
           'TransactionWebSocketServiceStub should never be instantiated'),
       );
  
  @override
  Future<void> initialize() async {
    // Stub implementation for non-web platforms
  }

  @override
  Future<void> dispose() async {
    // Stub implementation for non-web platforms
  }
}

/// Creates a web-specific WebSocket service
/// This function is used for testing and by the service factory
TransactionWebSocketServiceImpl createWebSocketService({
  required String webSocketUrl,
  int reconnectIntervalMs = 5000,
  int maxReconnectAttempts = 5,
  WebSocketChannelFactory? webSocketChannelFactory,
}) {
  return TransactionWebSocketServiceImpl(
    webSocketUrl: webSocketUrl,
    reconnectIntervalMs: reconnectIntervalMs,
    maxReconnectAttempts: maxReconnectAttempts,
    webSocketChannelFactory: webSocketChannelFactory,
  );
}
