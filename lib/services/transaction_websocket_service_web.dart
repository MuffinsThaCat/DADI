// ignore_for_file: implementation_imports, avoid_web_libraries_in_flutter
// This file intentionally uses web-only libraries (dart:html and web_socket_channel/html) 
// as it's specifically designed for the web platform implementation

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
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
  StreamSubscription<html.Event>? _onlineSubscription;
  
  /// Subscription for offline events
  StreamSubscription<html.Event>? _offlineSubscription;
  
  /// Subscription for focus events
  StreamSubscription<html.Event>? _focusSubscription;
  
  /// Subscription for blur events
  StreamSubscription<html.Event>? _blurSubscription;
  
  /// Timer for sending ping messages
  Timer? _pingTimer;
  
  /// Interval for ping messages in milliseconds (default: 30 seconds)
  final int _pingIntervalMs;
  
  /// Constructor with web-specific defaults
  TransactionWebSocketServiceImpl({
    required String webSocketUrl,
    WebSocketChannel Function(Uri)? webSocketChannelFactory,
    bool useMockMode = false,
    int reconnectDelay = 3000,
    int maxReconnectAttempts = 10,
    int pingIntervalMs = 30000,
  }) : _pingIntervalMs = pingIntervalMs,
       super(
         webSocketUrl: webSocketUrl,
         webSocketChannelFactory: webSocketChannelFactory,
         useMockMode: useMockMode,
       ) {
    _setupBrowserEventListeners();
    _startPingTimer();
  }
  
  /// Set up browser-specific event listeners
  void _setupBrowserEventListeners() {
    // Listen for visibility changes
    _visibilityChangeSubscription = html.document.onVisibilityChange.listen((_) {
      _handleVisibilityChange();
    });
    
    // Listen for online/offline events
    _onlineSubscription = html.window.onOnline.listen((_) {
      _log('Browser online event detected');
      if (!isConnected) {
        connectWebSocket();
      }
    });
    
    _offlineSubscription = html.window.onOffline.listen((_) {
      _log('Browser offline event detected');
      // No need to disconnect, the connection will fail naturally
    });
    
    // Listen for focus/blur events
    _focusSubscription = html.window.onFocus.listen((_) {
      _log('Browser focus event detected');
      if (!isConnected) {
        connectWebSocket();
      }
    });
    
    _blurSubscription = html.window.onBlur.listen((_) {
      _log('Browser blur event detected');
      // Keep connection alive even when tab is not focused
    });
  }
  
  /// Start the ping timer
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(milliseconds: _pingIntervalMs), (_) {
      sendPingMessage({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
  
  /// Helper method to send a ping message
  @override
  void sendPingMessage(Map<String, dynamic> message) {
    if (isConnected) {
      _log('Sending ping message');
      try {
        final wsChannel = channel;
        if (wsChannel != null) {
          wsChannel.sink.add(jsonEncode(message));
        }
      } catch (e) {
        _log('Error sending ping message: $e');
      }
    }
  }
  
  /// Handle visibility change events
  void _handleVisibilityChange() {
    final isVisible = html.document.visibilityState == 'visible';
    _log('Visibility changed: ${isVisible ? 'visible' : 'hidden'}');
    
    if (isVisible && !isConnected) {
      _log('Document became visible, reconnecting WebSocket');
      connectWebSocket();
    }
  }
  
  /// Log a message with the TransactionWebSocketServiceWeb prefix
  void _log(String message) {
    debugPrint('TransactionWebSocketServiceWeb: $message');
  }
  
  @override
  Future<void> dispose() async {
    _pingTimer?.cancel();
    _visibilityChangeSubscription?.cancel();
    _onlineSubscription?.cancel();
    _offlineSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    await super.dispose();
  }
}

// Conditional stub implementation for non-web platforms
class TransactionWebSocketServiceStub extends TransactionWebSocketService {
  /// Constructor
  TransactionWebSocketServiceStub({
    required String webSocketUrl,
  }) : super(
         webSocketUrl: webSocketUrl,
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

/// Factory function to create a web-specific WebSocket service
TransactionWebSocketService createWebSocketService({
  required String webSocketUrl,
  required WebSocketChannelFactory webSocketChannelFactory,
  bool useMockMode = false,
}) {
  return TransactionWebSocketServiceImpl(
    webSocketUrl: webSocketUrl,
    webSocketChannelFactory: webSocketChannelFactory,
    useMockMode: useMockMode,
  );
}
