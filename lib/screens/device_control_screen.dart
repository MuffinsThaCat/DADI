import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_connector_interface.dart';
import '../widgets/wavy_background.dart';

/// A platform-agnostic implementation of the device control screen
/// Uses DeviceConnectorInterface to work on both web and mobile platforms
class DeviceControlScreen extends StatefulWidget {
  final String deviceId;
  final DateTime endTime;

  const DeviceControlScreen({
    super.key,
    required this.deviceId,
    required this.endTime,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> with SingleTickerProviderStateMixin {
  double _intensity = 0.0;
  bool _isConnected = false;
  Timer? _controlTimer;
  String? _currentDeviceId;
  late AnimationController _pulseAnimation;
  
  // Platform-agnostic fields for device control
  String _selectedCommandType = 'raw';
  double _testCommandValue = 10;
  final TextEditingController _customCommandController = TextEditingController();
  String? _testCommandStatus;
  bool _testCommandSuccess = false;

  @override
  void initState() {
    super.initState();
    
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _setupDeviceConnection();
    _setupControlTimer();
  }

  void _setupDeviceConnection() async {
    // Try to connect to the device
    final connector = Provider.of<DeviceConnectorInterface>(context, listen: false);
    
    try {
      await connector.connectToDevice(widget.deviceId);
      
      setState(() {
        _isConnected = connector.isConnected;
        _currentDeviceId = connector.currentDevice;
      });
      
      if (connector.isConnected) {
        debugPrint('Connected to device: ${widget.deviceId}');
      } else {
        debugPrint('Failed to connect to device: ${widget.deviceId}');
      }
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _setupControlTimer() {
    // Set up a timer to control the device based on intensity
    _controlTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isConnected || _intensity <= 0) return;
      
      final connector = Provider.of<DeviceConnectorInterface>(context, listen: false);
      connector.startVibration(_intensity);
    });
  }

  void _stopVibration() {
    final connector = Provider.of<DeviceConnectorInterface>(context, listen: false);
    connector.stopVibration();
    setState(() {
      _intensity = 0;
    });
  }

  void _disconnectDevice() async {
    final connector = Provider.of<DeviceConnectorInterface>(context, listen: false);
    
    try {
      await connector.disconnect();
      setState(() {
        _isConnected = false;
        _currentDeviceId = null;
      });
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }
  }

  Future<void> _handleCustomCommand() async {
    if (!_isConnected) {
      setState(() {
        _testCommandStatus = 'Device not connected';
        _testCommandSuccess = false;
      });
      return;
    }

    final connector = Provider.of<DeviceConnectorInterface>(context, listen: false);
    
    try {
      bool success = false;
      String status = 'Command failed';
      
      if (_selectedCommandType == 'raw') {
        // Parse the hex string to bytes
        final String hexStr = _customCommandController.text.replaceAll(' ', '');
        final List<int> bytes = [];
        
        for (int i = 0; i < hexStr.length; i += 2) {
          if (i + 2 <= hexStr.length) {
            final byte = int.parse(hexStr.substring(i, i + 2), radix: 16);
            bytes.add(byte);
          }
        }
        
        // Since we don't have a direct raw command method, we'll simulate it
        // by mapping the first byte to intensity (if possible)
        if (bytes.isNotEmpty) {
          final intensity = bytes[0] / 255.0;
          await connector.startVibration(intensity);
          success = connector.currentVibration > 0;
          status = success ? 'Raw command interpreted as intensity' : 'Failed to send raw command';
        } else {
          status = 'Invalid hex string';
          success = false;
        }
      } else if (_selectedCommandType == 'intensity') {
        // Send an intensity command
        final intensity = _testCommandValue / 100.0;
        await connector.startVibration(intensity);
        success = connector.currentVibration > 0;
        status = success ? 'Intensity command sent' : 'Failed to send intensity command';
      } else if (_selectedCommandType == 'pattern') {
        // Pattern implementation using the available interface methods
        // Since we don't have a direct pattern method, we'll simulate it
        try {
          for (double intensity in [0.3, 0.0, 0.5, 0.0, 0.7, 0.0, 1.0, 0.0]) {
            await connector.startVibration(intensity);
            await Future.delayed(const Duration(milliseconds: 300));
          }
          await connector.stopVibration();
          success = true;
          status = 'Pattern sequence completed';
        } catch (e) {
          success = false;
          status = 'Pattern sequence failed: $e';
        }
      }
      
      setState(() {
        _testCommandStatus = status;
        _testCommandSuccess = success;
      });
    } catch (e) {
      setState(() {
        _testCommandStatus = 'Error: $e';
        _testCommandSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    _pulseAnimation.dispose();
    _customCommandController.dispose();
    _stopVibration();
    _disconnectDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: _isConnected ? _disconnectDevice : _setupDeviceConnection,
            tooltip: _isConnected ? 'Disconnect' : 'Connect',
          ),
        ],
      ),
      body: Stack(
        children: [
          WavyBackground(child: Container(), primaryColor: Colors.blue.withOpacity(0.3), secondaryColor: Colors.purple.withOpacity(0.2)),
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Column(
        children: [
          _buildConnectionStatus(),
          _buildIntensityControls(),
          _buildCustomCommandsSection(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final Color statusColor = _isConnected ? Colors.green : Colors.red;
    final String statusText = _isConnected 
        ? 'Connected to: ${_currentDeviceId ?? ''}'
        : 'Not connected';
        
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _isConnected ? 0.3 + (_pulseAnimation.value * 0.7) : 0.3,
                child: Icon(
                  Icons.bluetooth,
                  color: statusColor,
                  size: 24,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Intensity Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.vibration),
              Expanded(
                child: Slider(
                  value: _intensity,
                  onChanged: _isConnected 
                      ? (value) {
                          setState(() => _intensity = value);
                        }
                      : null,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(_intensity * 100).round()}%',
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${(_intensity * 100).round()}%',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isConnected ? () => setState(() => _intensity = 0.2) : null,
                child: const Text('Low'),
              ),
              ElevatedButton(
                onPressed: _isConnected ? () => setState(() => _intensity = 0.5) : null,
                child: const Text('Medium'),
              ),
              ElevatedButton(
                onPressed: _isConnected ? () => setState(() => _intensity = 0.8) : null,
                child: const Text('High'),
              ),
              ElevatedButton(
                onPressed: _isConnected ? () => setState(() => _intensity = 0.0) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCommandsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced Controls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: _selectedCommandType,
            isExpanded: true,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCommandType = newValue;
                });
              }
            },
            items: <String>['raw', 'intensity', 'pattern']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase()),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_selectedCommandType == 'raw')
            TextField(
              controller: _customCommandController,
              decoration: const InputDecoration(
                labelText: 'Hex Command (e.g., FF 00 A1)',
                hintText: 'Enter hex bytes separated by spaces',
                border: OutlineInputBorder(),
              ),
            )
          else if (_selectedCommandType == 'intensity')
            Column(
              children: [
                Text('Intensity: ${_testCommandValue.round()}%'),
                Slider(
                  value: _testCommandValue,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: _testCommandValue.round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _testCommandValue = value;
                    });
                  },
                ),
              ],
            )
          else if (_selectedCommandType == 'pattern')
            const Text('Will send a predefined pattern'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isConnected ? _handleCustomCommand : null,
                  child: const Text('Send Command'),
                ),
              ),
            ],
          ),
          if (_testCommandStatus != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _testCommandSuccess ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testCommandStatus!,
                style: TextStyle(
                  color: _testCommandSuccess ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
