// This is a stub file for web_socket_channel to be used on non-web platforms
// It provides the minimum implementation needed for tests to compile

import 'dart:async';

/// A stub implementation of WebSocketChannel for non-web platforms
abstract class WebSocketChannel {
  /// The stream of messages received from the WebSocket
  Stream get stream;
  
  /// The sink for sending messages to the WebSocket
  WebSocketSink get sink;
}

/// A stub implementation of WebSocketSink for non-web platforms
abstract class WebSocketSink implements StreamSink<dynamic> {
  /// Closes the WebSocket connection
  Future<void> close([int? closeCode, String? closeReason]);
}

/// A stub implementation of StreamSink for non-web platforms
abstract class StreamSink<T> {
  /// Adds a value to the sink
  void add(T data);
  
  /// Adds an error to the sink
  void addError(Object error, [StackTrace? stackTrace]);
  
  /// Adds a stream to the sink
  Future<void> addStream(Stream<T> stream);
  
  /// Closes the sink
  Future<void> close();
  
  /// Future that completes when the sink is closed
  Future<void> get done;
}
