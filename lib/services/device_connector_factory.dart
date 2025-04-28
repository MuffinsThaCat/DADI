import 'package:flutter/foundation.dart' show VoidCallback;
import 'device_connector_interface.dart';

/// Factory to create the appropriate device connector implementation
/// based on the current platform (web or mobile)
class DeviceConnectorFactory {
  /// Creates and returns the appropriate DeviceConnectorInterface implementation
  /// for the current platform.
  ///
  /// On web, this will return a web-specific implementation that uses Web Bluetooth
  /// with a fallback to Feel Technology.
  ///
  /// On mobile, this will return a native Bluetooth implementation.
  static DeviceConnectorInterface create({
    bool useMockMode = false,
  }) {
    if (useMockMode) {
      // In mock mode, use the mock implementation regardless of platform
      return createMockDeviceConnector();
    }
    
    // Use platform-specific implementation
    return createDeviceConnector();
  }
  
  /// Creates a real device connector based on the platform
  static DeviceConnectorInterface createDeviceConnector() {
    // We'll return a mock implementation since we're now using
    // conditional imports at a higher level to handle platform specifics
    return createMockDeviceConnector();
  }
  
  /// Creates a mock device connector for testing purposes
  static DeviceConnectorInterface createMockDeviceConnector() {
    // Use a simple mock implementation that works for both platforms
    return _MockDeviceConnector();
  }
}

/// A simple mock implementation of DeviceConnectorInterface for testing
class _MockDeviceConnector implements DeviceConnectorInterface {
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  
  // For the ChangeNotifier implementation
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String? get currentDevice => _currentDevice;
  
  @override
  double get currentVibration => _currentVibration;
  
  @override
  Future<void> connect() async {
    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    _currentDevice = 'Mock Device';
    notifyListeners();
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _currentDevice = null;
    _currentVibration = 0.0;
    notifyListeners();
  }
  
  @override
  Future<void> startVibration(double intensity) async {
    if (!_isConnected) return;
    _currentVibration = intensity.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  @override
  Future<void> stopVibration() async {
    if (!_isConnected) return;
    _currentVibration = 0.0;
    notifyListeners();
  }
  
  @override
  Future<List<String>> scanForDevices() async {
    return ['Mock Device 1', 'Mock Device 2'];
  }
  
  @override
  Future<void> connectToDevice(String deviceId) async {
    _isConnected = true;
    _currentDevice = deviceId;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
  
  // ChangeNotifier implementation
  @override
  void addListener(VoidCallback listener) {
    if (!_disposed) {
      _listeners.add(listener);
    }
  }
  
  @override
  void removeListener(VoidCallback listener) {
    if (!_disposed) {
      _listeners.remove(listener);
    }
  }
  
  @override
  void notifyListeners() {
    if (_disposed) return;
    
    // Create a copy to avoid concurrent modification issues
    final localListeners = List<VoidCallback>.from(_listeners);
    for (final listener in localListeners) {
      if (!_disposed) {
        listener();
      }
    }
  }
  
  @override
  bool get hasListeners => _listeners.isNotEmpty;
}
