import 'dart:async';
import 'package:flutter/foundation.dart';

class MockButtplugService extends ChangeNotifier {
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  Timer? _vibrationTimer;

  bool get isConnected => _isConnected;
  String? get currentDevice => _currentDevice;
  double get currentVibration => _currentVibration;

  Future<void> connect() async {
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    _currentDevice = 'Mock Device 1';
    notifyListeners();
  }

  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = false;
    _currentDevice = null;
    _stopVibration();
    notifyListeners();
  }

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

  Future<List<String>> scanForDevices() async {
    await Future.delayed(const Duration(seconds: 2));
    return ['Mock Device 1', 'Mock Device 2', 'Mock Device 3'];
  }

  Future<void> connectToDevice(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentDevice = deviceId;
    notifyListeners();
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    super.dispose();
  }
}
