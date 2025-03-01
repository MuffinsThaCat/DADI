// This file exports the appropriate implementation based on the platform
// For web, it exports transaction_websocket_service_web.dart
// For non-web, it exports transaction_websocket_service_io.dart

export 'transaction_websocket_service_io.dart'
  if (dart.library.html) 'transaction_websocket_service_web.dart';
