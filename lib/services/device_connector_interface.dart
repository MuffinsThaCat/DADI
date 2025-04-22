import 'package:flutter/foundation.dart';

/// Common interface for device connectivity across platforms
abstract class DeviceConnectorInterface extends ChangeNotifier {
  /// Whether the service is connected to a device
  bool get isConnected;
  
  /// Current device identifier if connected
  String? get currentDevice;
  
  /// Current vibration intensity (0.0 - 1.0)
  double get currentVibration;
  
  /// Connect to a device
  Future<void> connect();
  
  /// Disconnect from device
  Future<void> disconnect();
  
  /// Start vibration with specified intensity (0.0 - 1.0)
  Future<void> startVibration(double intensity);
  
  /// Stop vibration
  Future<void> stopVibration();
  
  /// Scan for available devices
  Future<List<String>> scanForDevices();
  
  /// Connect to a specific device by ID
  Future<void> connectToDevice(String deviceId);
}
