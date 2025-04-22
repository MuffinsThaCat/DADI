import 'dart:async';
import 'dart:developer' as developer;
import 'dart:html' as html; // Flutter web requires this library
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:js/js_util.dart' as js_util;
import 'device_connector_interface.dart';

// Custom callback for connection code display - will be set by the settings screen
typedef ConnectionCodeDisplayCallback = void Function(String connectionCode);

/// Available connection strategies for web implementation
enum ConnectionStrategy {
  webBluetooth // Using Web Bluetooth API directly
}

/// Implementation of [DeviceConnectorInterface] for web platforms
/// with both WebBluetooth and Feel Technology support
class DeviceConnectorWeb extends ChangeNotifier implements DeviceConnectorInterface {
  // Debug mode
  static bool debugMode = true;
  
  // Connection code display callback
  static ConnectionCodeDisplayCallback? onConnectionCodeRequested;
  
  // Core state properties
  bool _isConnected = false;
  String? _currentDevice;
  double _currentVibration = 0.0;
  Timer? _vibrationTimer;
  
  // Connection properties
  bool _isConnectingOrConnected = false;
  // Flag to track if disconnection was intentional vs connection lost
  bool _isIntentionallyDisconnected = false; // Used when handling reconnection logic
  int _reconnectionAttempts = 0;
  Timer? _reconnectionTimer;
  Timer? _heartbeatTimer;
  final int _heartbeatIntervalMs = 5000;
  final int _maxReconnectionAttempts = 5;
  bool _wasConnectedBeforeHidden = false;
  
  // Web Bluetooth specific properties
  dynamic _bluetoothDevice;
  dynamic _vibrateCharacteristic;
  
  // Feel Technology fallback flag
  bool _useFeelTechnologyFallback = false;
  
  // Page visibility and connection state tracking
  StreamSubscription<html.Event>? _visibilityChangeSubscription;
  StreamSubscription<html.Event>? _onlineStateSubscription;
  
  // Interface getters implementation
  @override
  bool get isConnected => _isConnected;
  
  @override
  String? get currentDevice => _currentDevice;
  
  @override
  double get currentVibration => _currentVibration;
  
  // Log with timestamp for easier debugging
  void _log(String message) {
    if (debugMode) {
      // Use developer.log instead of print for better debugging
      developer.log(message, name: 'DeviceConnectorWeb');
    }
  }
  
  // Debug helper for DOM console
  void _addConsoleDebug(String message) {
    if (debugMode) {
      js_util.callMethod(html.window.console, 'log', ['[Device Connector] $message']);
    }
  }
  
  DeviceConnectorWeb() {
    // Check if Web Bluetooth is supported but proceed regardless
    final hasWebBluetooth = _checkWebBluetoothSupport();
    _log('DeviceConnectorWeb initialized (Web Bluetooth support: $hasWebBluetooth)');
    
    // Pre-load Feel Technology JS just in case we need it as fallback
    _loadFeelTechnologyJs();
    
    // Initialize state tracking for better connection reliability
    _initializeStateTracking();
  }
  
  /// Initialize page visibility and online state tracking
  void _initializeStateTracking() {
    // Track page visibility changes
    _visibilityChangeSubscription = html.document.onVisibilityChange.listen((event) {
      if (html.document.visibilityState == 'visible') {
        _log('Page became visible');
        if (_wasConnectedBeforeHidden && !_isConnected && _bluetoothDevice != null) {
          _log('Attempting to reconnect after page became visible');
          _attemptReconnection();
        }
      } else if (html.document.visibilityState == 'hidden') {
        _log('Page hidden');
        _wasConnectedBeforeHidden = _isConnected;
      }
    });

    // Track online/offline status
    _onlineStateSubscription = html.window.onOnline.listen((event) {
      _log('Browser came online');
      if (_wasConnectedBeforeHidden && !_isConnected && _bluetoothDevice != null) {
        _log('Attempting to reconnect after browser came online');
        _attemptReconnection();
      }
    });
  }
  
  /// Loads the Feel Technology JavaScript library
  void _loadFeelTechnologyJs() {
    try {
      // Check if script is already loaded
      if (js_util.hasProperty(html.window, 'feelConnect')) {
        _log('Feel Technology JS already loaded');
        return;
      }
      
      _log('Loading Feel Technology JS library...');
      final script = html.ScriptElement()
        ..type = 'text/javascript'
        ..src = 'https://api.feel-app.com/static/feeljs/1.0/feel.min.js';
        
      // Set up load and error handlers
      script.onLoad.listen((event) {
        _log('Feel Technology JS library loaded successfully');
      });
      
      script.onError.listen((event) {
        _log('Error loading Feel Technology JS library');
      });
      
      // Add the script to the document head
      html.document.head?.append(script);
    } catch (e) {
      _log('Error setting up Feel Technology JS: $e');
    }
  }
  
  /// Check if Web Bluetooth is supported in this browser
  bool _checkWebBluetoothSupport() {
    try {
      // Try to detect if navigator.bluetooth is available
      final hasWebBluetooth = js_util.hasProperty(html.window.navigator, 'bluetooth');
      
      // Get browser details for logging
      final userAgent = html.window.navigator.userAgent;
      final browserDetails = userAgent.contains('Chrome') ? 'Chrome' : 
                           userAgent.contains('Firefox') ? 'Firefox' : 
                           userAgent.contains('Safari') ? 'Safari' : 'Unknown';
      
      _log('Web Bluetooth support check: $hasWebBluetooth (Browser: $browserDetails)');
      _addConsoleDebug('Web Bluetooth support detected: $hasWebBluetooth, Browser: $browserDetails');
      
      return hasWebBluetooth;
    } catch (e) {
      _log('Error checking Web Bluetooth support: $e');
      return false;
    }
  }
  
  /// Attempt to reconnect to the device
  void _attemptReconnection() {
    if (_reconnectionTimer != null || _reconnectionAttempts >= _maxReconnectionAttempts || _bluetoothDevice == null || _isIntentionallyDisconnected) {
      _log('Skipping reconnection: Already trying or max attempts reached or intentional disconnect');
      return;
    }
    
    _addConsoleDebug('Attempting reconnection $_reconnectionAttempts/$_maxReconnectionAttempts');
    _reconnectionAttempts++;
    
    try {
      // Get the GATT property from the device
      final gatt = js_util.getProperty(_bluetoothDevice, 'gatt');
      
      // Attempt reconnection
      js_util.promiseToFuture(
        js_util.callMethod(gatt, 'connect', [])
      ).then((server) {
        _log('Reconnection successful');
        _addConsoleDebug('Bluetooth reconnection successful');
        _isConnected = true;
        _reconnectionAttempts = 0;
        notifyListeners();
        
        // Re-establish characteristic if needed
        if (_vibrateCharacteristic == null) {
          _log('Re-establishing vibration characteristic');
          // This would require implementing a method to re-establish the characteristic
        }
      }).catchError((e) {
        _log('Reconnection attempt failed: $e');
        
        if (_reconnectionAttempts < _maxReconnectionAttempts) {
          // Exponential backoff for retry (500ms, 1s, 2s, 4s, 8s)
          final delay = Duration(milliseconds: 500 * (1 << (_reconnectionAttempts - 1)));
          _log('Will retry in $delay');
          
          _reconnectionTimer = Timer(delay, () {
            _reconnectionTimer = null;
            _attemptReconnection();
          });
        } else {
          _log('Maximum reconnection attempts reached');
          _reconnectionAttempts = 0;
        }
      });
    } catch (e) {
      _log('Error during reconnection: $e');
      _reconnectionAttempts = 0;
    }
  }
  
  // This method is maintained for compatibility with settings screen
  void setConnectionStrategy(ConnectionStrategy strategy) {
    _log('setConnectionStrategy called with $strategy (no-op)');
  }

  @override
  Future<void> connect() async {
    _log('connect() called');
    
    if (_isConnected) {
      _log('Already connected to a device');
      return;
    }
    
    if (_isConnectingOrConnected) {
      _log('Connection already in progress');
      return;
    }
    
    _isConnectingOrConnected = true;
    _isIntentionallyDisconnected = false; // Reset flag when starting new connection
    
    try {
      // First try Web Bluetooth
      if (_checkWebBluetoothSupport()) {
        try {
          _log('Attempting to connect with Web Bluetooth...');
          _addConsoleDebug('Trying Web Bluetooth connection first...');
          
          await _connectWithWebBluetooth();
          return; // Successfully connected
        } catch (webBluetoothError) {
          _log('Web Bluetooth connection failed: $webBluetoothError');
          _addConsoleDebug('Web Bluetooth failed: ${webBluetoothError.toString().substring(0, webBluetoothError.toString().length > 50 ? 50 : webBluetoothError.toString().length)}');
          _addConsoleDebug('Trying Feel Technology as fallback...');
          
          // If Web Bluetooth failed, try Feel Technology as fallback
          if (js_util.hasProperty(html.window, 'feelConnect')) {
            try {
              _log('Attempting to connect with Feel Technology...');
              _addConsoleDebug('Using Feel Technology connection');
              
              // Set up Feel Technology connection
              _useFeelTechnologyFallback = true;
              
              // Using window.feelConnect
              final feelConnect = js_util.getProperty(html.window, 'feelConnect');
              if (feelConnect != null) {
                final connectionResult = await js_util.promiseToFuture(
                  js_util.callMethod(feelConnect, 'connect', [])
                );
                
                if (connectionResult != null) {
                  _isConnected = true;
                  _currentDevice = 'Feel Technology Device';
                  _isConnectingOrConnected = false;
                  _addConsoleDebug('Connected with Feel Technology fallback');
                  notifyListeners();
                  return;
                }
              }
            } catch (feelError) {
              _log('Feel Technology connection failed: $feelError');
            }
          }
        }
      }
      
      // If all methods failed
      _log('All connection methods failed');
      _addConsoleDebug('All connection methods failed');
      _isConnectingOrConnected = false;
      throw Exception('Unable to connect: No compatible connection method available');
    } catch (e) {
      _isConnectingOrConnected = false;
      _log('Connection error: $e');
      
      // Create user-friendly message
      String userMessage = 'Connection failed';
      if (e.toString().contains('User cancelled')) {
        userMessage = 'Connection cancelled by user';
      } else if (e.toString().contains('Bluetooth adapter is not available')) {
        userMessage = 'Bluetooth is not available on this device';
      } else if (e.toString().contains('requestDevice error')) {
        userMessage = 'Error connecting to the device. Please try again.';
      }
      
      _addConsoleDebug('Connection failed: $userMessage');
      rethrow;
    }
  }
  
  // Connect with Web Bluetooth API
  Future<void> _connectWithWebBluetooth() async {
    _log('Connecting with Web Bluetooth');
    _addConsoleDebug('Starting Bluetooth connection process...');
    
    try {
      // Get the navigator.bluetooth property
      final bluetooth = js_util.getProperty(html.window.navigator, 'bluetooth');
      
      // Define service UUIDs to scan for
      final serviceUuids = [
        // Standard vibration service
        '00006000-0000-1000-8000-00805f9b34fb',
        // Lovense service
        '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
        // LVS-specific service
        '5fff1101-4733-91a3-ff78-31760d3c5191',
        // Generic access profile
        '00001800-0000-1000-8000-00805f9b34fb'
      ];
      
      // For device scanning
      final filters = <dynamic>[];
      final optionalServices = <String>[];
      
      // If name contains certain keywords, filter for specific devices
      filters.add(js_util.jsify({
        'services': serviceUuids
      }));

      // For name-based filters (Lovense, Hush, etc.)
      final nameFilters = ['Lovense', 'Hush', 'LVS'];
      for (final name in nameFilters) {
        filters.add(js_util.jsify({
          'namePrefix': name
        }));
      }
      
      // Add all common vibration-related service UUIDs as optional
      optionalServices.addAll([
        // Standard services
        '00006000-0000-1000-8000-00805f9b34fb',
        '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
        '5fff1101-4733-91a3-ff78-31760d3c5191',
        // Extra services for compatibility
        '0000180f-0000-1000-8000-00805f9b34fb', // Battery service
        '00001800-0000-1000-8000-00805f9b34fb', // Generic access
        '0000fff0-0000-1000-8000-00805f9b34fb'
      ]);
      
      _log('Starting device discovery with: ${filters.length} filters, ${optionalServices.length} optional services');
      _addConsoleDebug('Starting device discovery with expanded compatibility');
      
      _addConsoleDebug('Requesting device selection dialog...');
      final requestOptions = js_util.jsify({
        'filters': filters,
        'optionalServices': optionalServices
      });
      
      // Request the device - this will show the browser's Bluetooth device selection dialog
      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [requestOptions])
      );
      
      // Get the device name and ID
      final deviceName = js_util.getProperty(device, 'name') ?? 'Unknown Device';
      final deviceId = js_util.getProperty(device, 'id') ?? 'unknown_id';
      
      _log('Selected device: $deviceName (ID: $deviceId)');
      _addConsoleDebug('Device selected: $deviceName (ID: $deviceId)');
      
      // Connect to the GATT server
      final gatt = js_util.getProperty(device, 'gatt');
      final server = await js_util.promiseToFuture(
        js_util.callMethod(gatt, 'connect', [])
      );
      
      _log('GATT server connected');
      _addConsoleDebug('GATT server connection established');
      
      // Store the connected device
      _bluetoothDevice = device;
      _currentDevice = deviceName;
      
      // Keep track of whether we've found a compatible service
      var serviceFound = false; // Will be set to true if we find the appropriate service
      
      // Special handling for LVS-Hush devices which need a specific approach
      if (deviceName.contains('LVS-Hush') || deviceName.contains('Hush')) {
        _log('Detected LVS-Hush device, using specialized approach');
        
        try {
          // LVS-Hush specific service UUIDs
          const serviceUuid = '5fff1101-4733-91a3-ff78-31760d3c5191';
          const vibrateCharUuid = '5fff1102-4733-91a3-ff78-31760d3c5191';
          
          // Get the service
          final service = await js_util.promiseToFuture(
            js_util.callMethod(server, 'getPrimaryService', [serviceUuid])
          );
          
          // Get the characteristic
          final characteristic = await js_util.promiseToFuture(
            js_util.callMethod(service, 'getCharacteristic', [vibrateCharUuid])
          );
          
          // Store for later use
          _vibrateCharacteristic = characteristic;
          serviceFound = true; // Mark as found so we can log success below
          
          _log('Successfully connected to LVS-Hush vibration characteristic');
        } catch (e) {
          _log('Error connecting to LVS-Hush service: $e, will try generic approach');
        }
      }
      
      // Complete connection process
      _isConnected = true;
      _isConnectingOrConnected = false;
      
      if (serviceFound) {
        _log('Successfully connected to device with compatible service');
      } else {
        _log('Connected to device but no compatible vibration service found');
      }
      
      notifyListeners();
      
      _log('Connected to $_currentDevice via Web Bluetooth');
      
      // Start heartbeat
      _startHeartbeat();
      
      return;
    } catch (e) {
      _log('Error connecting with Web Bluetooth: $e');
      throw Exception('Web Bluetooth connection failed: $e');
    }
  }
  
  @override
  Future<void> disconnect() async {
    _log('disconnect() called');
    
    // Mark this as an intentional disconnect - this prevents automatic reconnection attempts
    _isIntentionallyDisconnected = true;
    
    if (!_isConnected) {
      _log('No device connected, nothing to disconnect from');
      return;
    }
    
    try {
      if (_useFeelTechnologyFallback) {
        // Disconnect using Feel Technology
        if (js_util.hasProperty(html.window, 'feelConnect')) {
          final feelConnect = js_util.getProperty(html.window, 'feelConnect');
          if (feelConnect != null) {
            await js_util.promiseToFuture(
              js_util.callMethod(feelConnect, 'disconnect', [])
            );
            _log('Disconnected from Feel Technology');
          }
        }
      } else if (_bluetoothDevice != null) {
        // First stop any ongoing vibration
        await stopVibration();
        
        _log('Disconnecting from Web Bluetooth device');
        
        // Clear the GATT connection (though this doesn't always work reliably in browsers)
        if (js_util.hasProperty(_bluetoothDevice, 'gatt')) {
          final gatt = js_util.getProperty(_bluetoothDevice, 'gatt');
          if (js_util.hasProperty(gatt, 'disconnect')) {
            js_util.callMethod(gatt, 'disconnect', []);
          }
        }
      }
    } catch (e) {
      _log('Error during disconnect: $e');
    } finally {
      // Clean up regardless of success/failure
      _isConnected = false;
      _currentVibration = 0.0;
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _heartbeatTimer?.cancel();
      
      // Reset device references
      _vibrateCharacteristic = null;
      
      notifyListeners();
      _log('Disconnected');
    }
  }
  
  @override
  Future<void> startVibration(double intensity) async {
    _log('startVibration called with intensity: $intensity');
    
    // Ensure connected
    if (!_isConnected) {
      _log('Not connected, cannot start vibration');
      throw Exception('Not connected to a device');
    }
    
    // Clamp intensity for safety
    final safeIntensity = intensity.clamp(0.0, 1.0);
    
    try {
      if (_useFeelTechnologyFallback) {
        // Use Feel Technology API
        await _startVibrationWithFeelTechnology(safeIntensity);
      } else if (_vibrateCharacteristic != null) {
        // Use Web Bluetooth
        
        // For Lovense devices including Hush
        if (_currentDevice?.contains('Lovense') == true || 
            _currentDevice?.contains('Hush') == true || 
            _currentDevice?.contains('LVS') == true) {
          
          // Specific vibration approach for LVS-Hush
          if (_currentDevice?.contains('LVS-Hush') == true || 
              _currentDevice?.contains('Hush') == true) {
            await _startVibrationWithLvsHush(safeIntensity);
          } else {
            // Generic Lovense approach
            await _startVibrationWithStandardBluetooth(safeIntensity);
          }
        } else {
          // Generic approach for other devices
          await _startVibrationWithStandardBluetooth(safeIntensity);
        }
      } else {
        throw Exception('No compatible vibration control available');
      }
      
      // Update state
      _currentVibration = safeIntensity;
      notifyListeners();
      
      // Auto-stop timer for safety (30 seconds max)
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer(const Duration(seconds: 30), () {
        stopVibration();
      });
      
    } catch (e) {
      _log('Error starting vibration: $e');
      throw Exception('Failed to start vibration: $e');
    }
  }
  
  // Start vibration using Feel Technology API
  Future<void> _startVibrationWithFeelTechnology(double intensity) async {
    if (debugMode) {
      developer.log('Starting vibration with Feel Technology, intensity: $intensity', name: 'DeviceConnectorWeb');
    }
    
    try {
      if (js_util.hasProperty(html.window, 'feelConnect')) {
        final feelConnect = js_util.getProperty(html.window, 'feelConnect');
        if (feelConnect != null) {
          // Convert 0.0-1.0 to 0-100% for Feel API
          final feelIntensity = (intensity * 100).round();
          await _sendFeelVibrationCommand(feelIntensity);
          if (debugMode) {
            developer.log('Feel Technology vibration started at $feelIntensity%', name: 'DeviceConnectorWeb');
          }
          return;
        }
      }
      throw Exception('Feel Technology not available');
    } catch (e) {
      if (debugMode) {
        developer.log('Error with Feel Technology vibration: $e', name: 'DeviceConnectorWeb');
      }
      rethrow;
    }
  }
  
  // Helper method to send Feel Technology vibration commands
  Future<void> _sendFeelVibrationCommand(int intensity) async {
    try {
      if (js_util.hasProperty(html.window, 'feelConnect')) {
        final feelConnect = js_util.getProperty(html.window, 'feelConnect');
        if (feelConnect != null) {
          // Create command object
          final command = js_util.jsify({
            'Command': 'VibrateCmd',
            'Id': 1,
            'DeviceIndex': 0,
            'Timeout': 30, // 30 seconds max
            'Speeds': [intensity]
          });
          
          await js_util.promiseToFuture(
            js_util.callMethod(feelConnect, 'sendFeelCommand', [command])
          );
        }
      }
    } catch (e) {
      if (debugMode) {
        developer.log('Error sending Feel vibration command: $e', name: 'DeviceConnectorWeb');
      }
    }
  }
  
  // Create a container for displaying the text connection code
  // This is used when we need to show the user a pairing code
  html.Element _createConnectionCodeContainer(String connectionCode) {
    _log('Creating text connection code container');
    // Remove any existing container
    final existingContainer = html.document.querySelector('#feel-connection-code-container');
    if (existingContainer != null) {
      existingContainer.remove();
    }
    
    // Create a wrapper container
    final wrapperContainer = html.DivElement()
      ..id = 'feel-connection-code-container'
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.8)'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.justifyContent = 'center'
      ..style.alignItems = 'center'
      ..style.zIndex = '9999';
      
    // Create a content container
    final contentContainer = html.DivElement()
      ..style.backgroundColor = 'white'
      ..style.padding = '20px'
      ..style.borderRadius = '10px'
      ..style.maxWidth = '90%'
      ..style.textAlign = 'center';
      
    // Create title
    final title = html.HeadingElement.h2()
      ..text = 'Connect Your Device'
      ..style.margin = '0 0 15px 0';
      
    // Create subtitle
    final subtitle = html.ParagraphElement()
      ..text = 'Enter this code in the FeelConnect app'
      ..style.margin = '0 0 20px 0';
      
    // Create connection code display
    final codeElement = html.DivElement()
      ..style.margin = '0 auto 20px auto'
      ..style.padding = '15px'
      ..style.backgroundColor = '#f5f5f5'
      ..style.borderRadius = '5px'
      ..style.fontSize = '24px'
      ..style.fontWeight = 'bold'
      ..style.letterSpacing = '2px'
      ..text = connectionCode;
      
    // Create close button
    final closeButton = html.ButtonElement()
      ..text = 'Close'
      ..style.padding = '10px 20px'
      ..style.backgroundColor = '#ff5722'
      ..style.color = 'white'
      ..style.border = 'none'
      ..style.borderRadius = '5px'
      ..style.cursor = 'pointer';
      
    // Add event listener to close button
    closeButton.onClick.listen((event) {
      _removeConnectionCodeContainer(wrapperContainer);
    });
    
    // Append elements to the content container
    contentContainer.children.addAll([title, subtitle, codeElement, closeButton]);
    
    // Append content container to wrapper
    wrapperContainer.children.add(contentContainer);
    
    // Append to the body
    html.document.body?.append(wrapperContainer);
    
    return wrapperContainer;
  }

  // Remove connection code container from the DOM
  // Called when the connection code is no longer needed to be displayed
  void _removeConnectionCodeContainer(html.Element container) {
    try {
      container.remove();
      _log('Connection code container removed');
    } catch (e) {
      _log('Error removing connection code container: $e');
    }
  }
  
  // Generate a random code for testing
  String _generateRandomCode(int length) {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final code = List.generate(length, (_) => characters[random.nextInt(characters.length)]);
    return code.join();
  }
  
  // Specialized method for LVS-Hush devices
  Future<void> _startVibrationWithLvsHush(double intensity) async {
    _log('Starting vibration on LVS-Hush device with intensity: $intensity');
    
    try {
      if (_vibrateCharacteristic == null) {
        throw Exception('No vibration characteristic available');
      }
      
      // Convert 0.0-1.0 to 0-20 scale used by LVS-Hush
      final lvsIntensity = (intensity * 20).round();
      _log('Converted intensity to LVS scale: $lvsIntensity');
      
      // LVS-Hush protocol uses command like: Vibrate:X;
      // where X is integer from 0-20
      final command = 'Vibrate:$lvsIntensity;';
      final bytes = Uint8List.fromList(command.codeUnits);
      
      // Send the command
      await js_util.promiseToFuture(
        js_util.callMethod(_vibrateCharacteristic, 'writeValue', [bytes.buffer])
      );
      
      _log('LVS-Hush vibration command sent: $command');
    } catch (e) {
      _log('Error sending LVS-Hush vibration command: $e');
      rethrow;
    }
  }
  
  // Standard method for regular Bluetooth vibration devices
  Future<void> _startVibrationWithStandardBluetooth(double intensity) async {
    _log('Starting standard vibration with intensity: $intensity');
    
    try {
      if (_vibrateCharacteristic == null) {
        throw Exception('No vibration characteristic available');
      }
      
      // Convert 0.0-1.0 to byte value (0-255)
      final byteIntensity = (intensity * 255).round();
      final bytes = Uint8List.fromList([byteIntensity]);
      
      // Send the command
      await js_util.promiseToFuture(
        js_util.callMethod(_vibrateCharacteristic, 'writeValue', [bytes.buffer])
      );
      
      _log('Standard vibration command sent: $byteIntensity');
    } catch (e) {
      _log('Error sending standard vibration command: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> stopVibration() async {
    _log('stopVibration called');
    
    // Only proceed if we're actually connected and vibrating
    if (!_isConnected) {
      _log('Not connected, nothing to stop');
      return;
    }
    
    try {
      if (_useFeelTechnologyFallback) {
        // Use Feel Technology API to stop
        if (js_util.hasProperty(html.window, 'feelConnect')) {
          final feelConnect = js_util.getProperty(html.window, 'feelConnect');
          if (feelConnect != null) {
            // Create stop command
            final stopCommand = js_util.jsify({
              'Command': 'StopDeviceCmd',
              'Id': 1,
              'DeviceIndex': 0
            });
            
            await js_util.promiseToFuture(
              js_util.callMethod(feelConnect, 'sendFeelCommand', [stopCommand])
            );
            _log('Feel Technology vibration stopped');
          }
        }
      } else if (_vibrateCharacteristic != null) {
        // For Lovense devices including Hush
        if (_currentDevice?.contains('LVS-Hush') == true || 
            _currentDevice?.contains('Hush') == true) {
          await _stopVibrationWithLvsHush();
        } else {
          // Generic approach - just send zero intensity
          await _startVibrationWithStandardBluetooth(0.0);
        }
      }
      
      // Clean up regardless of success/failure
      _currentVibration = 0.0;
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      notifyListeners();
      
      _log('Vibration stopped');
    } catch (e) {
      _log('Error stopping vibration: $e');
      // Don't throw, just log the error to prevent cascading failures
    }
  }
  
  // Specialized method to stop vibration on LVS-Hush devices
  Future<void> _stopVibrationWithLvsHush() async {
    _log('Stopping vibration on LVS-Hush device');
    
    try {
      if (_vibrateCharacteristic == null) {
        throw Exception('No vibration characteristic available');
      }
      
      // LVS-Hush protocol uses command like: Vibrate:0;
      const command = 'Vibrate:0;';
      final bytes = Uint8List.fromList(command.codeUnits);
      
      // Send the command
      await js_util.promiseToFuture(
        js_util.callMethod(_vibrateCharacteristic, 'writeValue', [bytes.buffer])
      );
      
      _log('LVS-Hush stop command sent: $command');
    } catch (e) {
      _log('Error sending LVS-Hush stop command: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<String>> scanForDevices() async {
    // Web platform doesn't support pre-scanning, device selection happens in connect()
    _log('scanForDevices called (not supported on web, scanning happens during connect)');
    return [];
  }
  
  @override
  Future<void> connectToDevice(String deviceId) async {
    // Web platform doesn't support direct device connection by ID
    // Instead, just call regular connect method
    _log('connectToDevice called with ID: $deviceId (using standard connect on web)');
    return connect();
  }
  
  // Simple heartbeat to maintain connection
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: _heartbeatIntervalMs), (_) {
      if (_isConnected) {
        _log('Connection heartbeat');
        // Could implement a healthcheck here
      }
    });
  }
  
  @override
  void dispose() {
    // Log cleanup
    if (debugMode) {
      developer.log('dispose() called', name: 'DeviceConnectorWeb');
    }
    
    // Clean up all resources
    _visibilityChangeSubscription?.cancel();
    _onlineStateSubscription?.cancel();
    _reconnectionTimer?.cancel();
    _vibrationTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    // Disconnect if connected
    if (isConnected) {
      disconnect();
    }
    
    super.dispose();
  }
}

/// Factory method to create a device connector for web
DeviceConnectorWeb createDeviceConnector() {
  return DeviceConnectorWeb();
}
