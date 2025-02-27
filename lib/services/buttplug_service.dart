import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ButtplugDevice {
  final String id;
  final String name;
  final List<String> messages;

  ButtplugDevice({
    required this.id,
    required this.name,
    required this.messages,
  });
}

class ButtplugService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final List<ButtplugDevice> _devices = [];
  String? _currentDevice;
  double _currentVibration = 0.0;

  bool get isConnected => _isConnected;
  List<ButtplugDevice> get devices => _devices;
  String? get currentDevice => _currentDevice;
  double get currentVibration => _currentVibration;

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:12345'),
      );

      await _sendMessage({
        'type': 'RequestServerInfo',
        'id': 1,
        'message': {'clientName': 'DADI Client', 'messageVersion': 3}
      });

      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (message) => _handleMessage(jsonDecode(message)),
        onError: (error) {
          debugPrint('WebSocket error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          disconnect();
        },
      );
    } catch (e) {
      debugPrint('Error connecting to Buttplug server: $e');
      disconnect();
    }
  }

  Future<void> disconnect() async {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _devices.clear();
    notifyListeners();
  }

  Future<void> startScanning() async {
    if (!_isConnected) return;

    await _sendMessage({
      'type': 'StartScanning',
      'id': 2,
    });
  }

  Future<void> stopScanning() async {
    if (!_isConnected) return;

    await _sendMessage({
      'type': 'StopScanning',
      'id': 3,
    });
  }

  Future<void> sendDeviceCommand(String deviceId, String command) async {
    if (!_isConnected) return;

    await _sendMessage({
      'type': 'DeviceMessage',
      'id': 4,
      'deviceId': deviceId,
      'message': command,
    });
  }

  Future<List<String>> scanForDevices() async {
    if (!_isConnected) {
      return [];
    }
    
    await startScanning();
    // In a real implementation, we would wait for device discovery events
    // For now, just return a mock list
    return _devices.map((device) => device.id).toList();
  }

  Future<void> connectToDevice(String deviceId) async {
    if (!_isConnected) return;
    
    // In a real implementation, we would send a command to connect to the device
    // For now, just store the device ID
    _currentDevice = deviceId;
    notifyListeners();
  }

  Future<void> startVibration(double intensity) async {
    if (!_isConnected) throw Exception('Not connected to device');
    if (_currentDevice == null) throw Exception('No device selected');
    if (intensity < 0 || intensity > 1) {
      throw Exception('Intensity must be between 0 and 1');
    }

    _currentVibration = intensity;
    
    // In a real implementation, we would send a command to the device
    await sendDeviceCommand(_currentDevice!, 'VibrateCmd ${intensity * 100}');
    notifyListeners();
  }

  Future<void> stopVibration() async {
    if (!_isConnected) throw Exception('Not connected to device');
    if (_currentDevice == null) throw Exception('No device selected');
    
    _currentVibration = 0.0;
    
    // In a real implementation, we would send a command to the device
    await sendDeviceCommand(_currentDevice!, 'VibrateCmd 0');
    notifyListeners();
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(message));
  }

  void _handleMessage(Map<String, dynamic> message) {
    // Handle incoming messages from the device
    // This will be implemented in a future update with proper message parsing and command handling
    debugPrint('Received message from device: ${jsonEncode(message)}');
  }
}
