import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'dart:html' as html;

/// Service for connecting to haptic devices through Feel Technology API
class FeelTechnologyService extends ChangeNotifier {
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  Timer? _vibrationTimer;
  bool _isScriptLoaded = false;
  
  bool get isConnected => _isConnected;
  String? get currentDevice => _currentDevice;
  double get currentVibration => _currentVibration;
  
  FeelTechnologyService() {
    _loadJsLibrary();
  }
  
  /// Loads the Feel Technology JavaScript library
  void _loadJsLibrary() {
    final script = html.document.createElement('script') as html.ScriptElement;
    script.type = 'text/javascript';
    script.src = 'https://api.feel-app.com/static/feeljs/1.0/feel.min.js';
    script.onLoad.listen((event) {
      debugPrint('Feel Technology JS library loaded successfully');
      _isScriptLoaded = true;
      notifyListeners();
    });
    script.onError.listen((event) {
      debugPrint('Error loading Feel Technology JS library: $event');
    });
    html.document.head?.append(script);
  }
  
  /// Connect to FeelConnect
  Future<void> connect() async {
    if (!_isScriptLoaded) {
      debugPrint('Feel Technology JS library not loaded yet, retrying in 1 second...');
      await Future.delayed(const Duration(seconds: 1));
      return connect();
    }
    
    try {
      // Call the Feel.js connect method which shows QR code for mobile connection
      // Using JS interop here
      final connectResult = await promiseToFuture(callMethod(
        html.window, 
        'feelConnect', 
        []
      ));
      
      if (connectResult != null) {
        _isConnected = true;
        _currentDevice = 'FeelConnect Device';
        notifyListeners();
        debugPrint('Connected to Feel Technology service');
        
        // Set up event listeners for device status
        _setupEventListeners();
      }
    } catch (e) {
      debugPrint('Error connecting to Feel Technology: $e');
      _isConnected = false;
      notifyListeners();
    }
  }
  
  /// Disconnect from Feel service
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    try {
      // Call disconnect method
      await promiseToFuture(callMethod(
        html.window, 
        'feelDisconnect', 
        []
      ));
      
      _stopVibration();
      _isConnected = false;
      _currentDevice = null;
      notifyListeners();
      debugPrint('Disconnected from Feel Technology service');
    } catch (e) {
      debugPrint('Error disconnecting from Feel Technology: $e');
    }
  }
  
  /// Setup event listeners for device connection changes
  void _setupEventListeners() {
    // Using JS interop to set up event listeners
    setProperty(html.window, 'onFeelDisconnect', allowInterop(() {
      debugPrint('Feel device disconnected event received');
      _isConnected = false;
      _currentDevice = null;
      notifyListeners();
    }));
  }
  
  /// Start vibration with given intensity
  Future<void> startVibration(double intensity) async {
    if (!_isConnected) throw Exception('Not connected to device');
    if (intensity < 0 || intensity > 1) {
      throw Exception('Intensity must be between 0 and 1');
    }
    
    try {
      // Convert intensity (0-1) to Feel API intensity format (0-100)
      final feelIntensity = (intensity * 100).round();
      
      // Send vibration command
      await promiseToFuture(callMethod(
        html.window,
        'feelSendCommand',
        [
          {
            'command': 'vibrate',
            'intensity': feelIntensity,
            'duration': 1000, // 1 second, will be repeated
          }
        ]
      ));
      
      _currentVibration = intensity;
      notifyListeners();
      
      // Set up repeated vibration to maintain continuous effect
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
        if (_isConnected && _currentVibration > 0) {
          // Keep sending commands to maintain vibration
          _sendVibrationCommand(feelIntensity);
        } else {
          _stopVibration();
        }
      });
    } catch (e) {
      debugPrint('Error starting vibration: $e');
    }
  }
  
  /// Helper to send vibration commands
  void _sendVibrationCommand(int intensity) {
    try {
      callMethod(
        html.window,
        'feelSendCommand',
        [
          {
            'command': 'vibrate',
            'intensity': intensity,
            'duration': 1000,
          }
        ]
      );
    } catch (e) {
      debugPrint('Error sending vibration command: $e');
    }
  }
  
  /// Stop vibration
  Future<void> stopVibration() async {
    if (!_isConnected) throw Exception('Not connected to device');
    
    try {
      // Send stop command
      await promiseToFuture(callMethod(
        html.window,
        'feelSendCommand',
        [
          {
            'command': 'stop',
          }
        ]
      ));
      
      _stopVibration();
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
    }
  }
  
  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _currentVibration = 0.0;
  }
  
  /// Scan for devices is not needed with Feel Technology
  /// as device pairing is handled by the mobile app
  Future<List<String>> scanForDevices() async {
    if (_isConnected) {
      return [_currentDevice!];
    }
    return [];
  }
  
  /// Connect to device automatically handled by QR code scan
  Future<void> connectToDevice(String deviceId) async {
    // No-op as connection is handled by the QR flow
    return;
  }
  
  @override
  void dispose() {
    _vibrationTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
