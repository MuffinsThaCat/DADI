import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_connector_interface.dart';

/// Mobile implementation of [DeviceConnectorInterface]
/// Uses flutter_reactive_ble for direct Bluetooth connectivity on mobile devices
class DeviceConnectorMobile extends ChangeNotifier implements DeviceConnectorInterface {
  // Core state properties
  bool _isConnected = false;
  String? _currentDevice;
  String? _currentDeviceId; // Used to store device ID for Bluetooth operations
  double _currentVibration = 0.0;
  Timer? _vibrationTimer;
  
  // Bluetooth specific properties
  final FlutterReactiveBle _ble = FlutterReactiveBle(); // Main BLE interface
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;
  final List<DiscoveredDevice> _discoveredDevices = [];
  
  // Commonly used service and characteristic UUIDs for haptic devices
  // These are standard UUIDs for vibration control, may need adjustment for specific device models
  static const String _vibrationServiceUuid = '00006000-0000-1000-8000-00805f9b34fb';
  static const String _vibrationCharacteristicUuid = '00006001-0000-1000-8000-00805f9b34fb';
  QualifiedCharacteristic? _vibrateCharacteristic;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String? get currentDevice => _currentDevice;
  
  @override
  double get currentVibration => _currentVibration;
  
  /// Returns a human-readable status of the device connection
  String get deviceStatus {
    if (!_isConnected) return 'Not connected';
    final deviceIdInfo = _currentDeviceId != null ? ' [ID: ${_currentDeviceId!.substring(0, 8)}...]' : '';
    return 'Connected to $_currentDevice$deviceIdInfo (${(_currentVibration * 100).toStringAsFixed(0)}% power)';
  }
  
  @override
  Future<void> connect() async {
    debugPrint('Mobile Bluetooth connect() called');
    
    try {
      // Request Bluetooth permissions
      final permissionStatus = await _requestPermissions();
      if (!permissionStatus) {
        throw Exception('Bluetooth permissions denied');
      }
      
      // Start scanning for devices
      final devices = await scanForDevices();
      
      if (devices.isNotEmpty) {
        // Connect to the first device found
        // In a real app, you would show a list to the user
        await connectToDevice(devices.first);
        return;
      } else {
        throw Exception('No Bluetooth devices found');
      }
    } catch (e) {
      debugPrint('Error connecting to Bluetooth device: $e');
      rethrow;
    }
  }
  
  // Helper method to request Bluetooth permissions
  Future<bool> _requestPermissions() async {
    // Request Bluetooth permissions
    final locationStatus = await Permission.location.request();
    final bluetoothStatus = await Permission.bluetooth.request();
    final bluetoothScanStatus = await Permission.bluetoothScan.request();
    final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    
    // Check if all required permissions are granted
    final allGranted = 
        locationStatus.isGranted && 
        bluetoothStatus.isGranted && 
        bluetoothScanStatus.isGranted && 
        bluetoothConnectStatus.isGranted;
    
    debugPrint('Bluetooth permissions ${allGranted ? 'granted' : 'denied'}');
    return allGranted;
  }
  
  // Setup device characteristics after connection
  Future<void> _setupCharacteristics(String deviceId) async {
    try {
      _vibrateCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(_vibrationServiceUuid),
        characteristicId: Uuid.parse(_vibrationCharacteristicUuid),
        deviceId: deviceId,
      );
      
      debugPrint('Setup characteristics completed');
    } catch (e) {
      debugPrint('Error setting up characteristics: $e');
    }
  }
  
  // Clean up resources on disconnection
  void _cleanupConnection() {
    _isConnected = false;
    _currentDevice = null;
    _currentDeviceId = null;
    _vibrateCharacteristic = null;
    _stopVibration();
    notifyListeners();
  }
  
  @override
  Future<void> disconnect() async {
    debugPrint('Mobile Bluetooth disconnect() called');
    
    // Cancel vibration if active
    await stopVibration();
    
    // Cancel active subscriptions
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    
    _cleanupConnection();
    debugPrint('Disconnected from Bluetooth device');
  }
  
  @override
  Future<void> startVibration(double intensity) async {
    debugPrint('Mobile Bluetooth startVibration($intensity) called');
    if (!_isConnected) throw Exception('Not connected to device');
    if (intensity < 0 || intensity > 1) {
      throw Exception('Intensity must be between 0 and 1');
    }
    
    if (_vibrateCharacteristic == null) {
      throw Exception('Device characteristics not available');
    }
    
    try {
      // Convert intensity (0.0-1.0) to byte value (0-255)
      final byteValue = (intensity * 255).round();
      final data = Uint8List.fromList([byteValue]);
      
      // Cancel any existing vibration timer
      _vibrationTimer?.cancel();
      
      // Write value to characteristic
      await _ble.writeCharacteristicWithoutResponse(_vibrateCharacteristic!, value: data);
      
      _currentVibration = intensity;
      notifyListeners();
      
      // Some devices need periodic commands to maintain vibration
      // Create a timer to send commands every second
      _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!_isConnected || _currentVibration <= 0) {
          timer.cancel();
          return;
        }
        
        try {
          await _ble.writeCharacteristicWithoutResponse(_vibrateCharacteristic!, value: data);
        } catch (e) {
          debugPrint('Error in vibration maintenance: $e');
          timer.cancel();
        }
      });
      
      debugPrint('Vibration started at intensity $intensity');
    } catch (e) {
      debugPrint('Error starting vibration: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> stopVibration() async {
    debugPrint('Mobile Bluetooth stopVibration() called');
    if (!_isConnected) return;
    
    try {
      if (_vibrateCharacteristic != null) {
        // Send 0 intensity to stop vibration
        final data = Uint8List.fromList([0]);
        await _ble.writeCharacteristicWithoutResponse(_vibrateCharacteristic!, value: data);
      }
      
      _stopVibration();
      debugPrint('Vibration stopped');
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
      // Still attempt to clean up internal state even if the BLE command fails
      _stopVibration();
    }
  }
  
  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _currentVibration = 0.0;
  }
  
  @override
  Future<List<String>> scanForDevices() async {
    debugPrint('Mobile Bluetooth scanForDevices() called');
    final completer = Completer<List<String>>();
    final deviceNames = <String>[];
    _discoveredDevices.clear();
    
    try {
      // Request Bluetooth permissions
      final permissionStatus = await _requestPermissions();
      if (!permissionStatus) {
        return [];
      }
      
      // Cancel any existing scan
      await _scanSubscription?.cancel();
      
      // Start a new scan with 10-second timeout
      _scanSubscription = _ble.scanForDevices(
        withServices: [Uuid.parse(_vibrationServiceUuid)],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          // Add device if it's not already in the list
          if (!_discoveredDevices.any((d) => d.id == device.id)) {
            _discoveredDevices.add(device);
            deviceNames.add(device.name.isNotEmpty ? device.name : 'Unknown Device (${device.id})');
            debugPrint('Found device: ${device.name} (${device.id})');
          }
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          if (!completer.isCompleted) {
            completer.complete(deviceNames);
          }
        },
      );
      
      // Set a timeout for the scan
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          _scanSubscription?.cancel();
          completer.complete(deviceNames);
          debugPrint('Scan completed with ${deviceNames.length} devices found');
        }
      });
      
      return completer.future;
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
      return [];
    }
  }
  
  @override
  Future<void> connectToDevice(String deviceId) async {
    debugPrint('Mobile Bluetooth connectToDevice($deviceId) called');
    
    try {
      // Find the device in our discovered devices list
      final device = _discoveredDevices.firstWhere(
        (d) => d.name == deviceId || d.id == deviceId,
        orElse: () => throw Exception('Device not found')
      );
      
      // Cancel any existing connection
      await disconnect();
      
      debugPrint('Connecting to ${device.name} (${device.id})');
      
      // Connect to the device
      _connectionSubscription = _ble.connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 10),
      ).listen(
        (connectionState) {
          debugPrint('Connection state: $connectionState');
          
          // Handle connection state changes
          switch (connectionState.connectionState) {
            case DeviceConnectionState.connected:
              _isConnected = true;
              _currentDevice = device.name;
              _currentDeviceId = device.id;
              notifyListeners();
              _setupCharacteristics(device.id);
              break;
            case DeviceConnectionState.disconnected:
              _cleanupConnection();
              break;
            default:
              // Connecting or disconnecting - no action needed
              break;
          }
        },
        onError: (error) {
          debugPrint('Connection error: $error');
          _cleanupConnection();
        },
      );
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _vibrationTimer?.cancel();
    super.dispose();
  }
}

/// Helper to create the mobile device connector
DeviceConnectorInterface createDeviceConnector() {
  return DeviceConnectorMobile();
}

/// Helper to create a mock device connector
DeviceConnectorInterface createMockDeviceConnector() {
  return MockDeviceConnector();
}

/// Mock implementation for testing
class MockDeviceConnector extends ChangeNotifier implements DeviceConnectorInterface {
  // Core state properties for mock functionality
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  Timer? _vibrationTimer;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String? get currentDevice => _currentDevice;
  
  @override
  double get currentVibration => _currentVibration;
  
  /// Returns a human-readable status of the device connection
  String get deviceStatus {
    if (!_isConnected) return 'Not connected';
    final deviceIdInfo = _currentDeviceId != null ? ' [ID: ${_currentDeviceId!.substring(0, 8)}...]' : '';
    return 'Connected to $_currentDevice$deviceIdInfo (${(_currentVibration * 100).toStringAsFixed(0)}% power)';
  }
  
  String? _currentDeviceId;
  
  @override
  Future<void> connect() async {
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    _currentDevice = 'Mock Device 1';
    _currentDeviceId = 'Mock Device ID';
    notifyListeners();
  }
  
  @override
  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = false;
    _currentDevice = null;
    _stopVibration();
    notifyListeners();
  }
  
  @override
  Future<void> startVibration(double intensity) async {
    if (!_isConnected) throw Exception('Not connected to device');
    if (intensity < 0 || intensity > 1) {
      throw Exception('Intensity must be between 0 and 1');
    }
    
    _currentVibration = intensity;
    notifyListeners();
    
    // Simulate device feedback
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _currentVibration = (_currentVibration * 0.9).clamp(0.0, 1.0);
      if (_currentVibration < 0.05) {
        _stopVibration();
      }
      notifyListeners();
    });
  }
  
  @override
  Future<void> stopVibration() async {
    if (!_isConnected) throw Exception('Not connected to device');
    _stopVibration();
    notifyListeners();
  }
  
  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _currentVibration = 0.0;
  }
  
  @override
  Future<List<String>> scanForDevices() async {
    await Future.delayed(const Duration(seconds: 1));
    return ['Mock Device 1', 'Mock Device 2', 'Mock Device 3'];
  }
  
  @override
  Future<void> connectToDevice(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentDevice = deviceId;
    _isConnected = true;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _vibrationTimer?.cancel();
    super.dispose();
  }
}
