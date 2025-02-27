import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_buttplug_service.dart';

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

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  double _intensity = 0.0;
  bool _isConnected = false;
  Timer? _controlTimer;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    // Start timer to check control period
    _controlTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Check if control period has expired
          if (DateTime.now().isAfter(widget.endTime) && _intensity > 0) {
            _intensity = 0;
            final buttplug = context.read<MockButtplugService>();
            buttplug.stopVibration();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    final buttplug = context.read<MockButtplugService>();
    try {
      if (!buttplug.isConnected) {
        await buttplug.connect();
      }
      setState(() {
        _isConnected = buttplug.isConnected;
        _currentDeviceId = buttplug.currentDevice;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to device: $e')),
        );
      }
    }
  }

  bool get _hasControl {
    final now = DateTime.now();
    return now.isBefore(widget.endTime);
  }

  void _updateIntensity(double value) {
    setState(() => _intensity = value);
    final buttplug = context.read<MockButtplugService>();
    if (value > 0) {
      buttplug.startVibration(value);
    } else {
      buttplug.stopVibration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttplug = context.watch<MockButtplugService>();
    final remainingTime = widget.endTime.difference(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusIndicator(
              'Device Connection',
              _isConnected,
              subtitle: _currentDeviceId != null ? 'Device ID: ${_currentDeviceId!}' : null,
            ),
            _buildStatusIndicator(
              'Control Period',
              _hasControl,
              subtitle: _hasControl
                  ? 'Time remaining: ${_formatDuration(remainingTime)}'
                  : 'Control period has ended',
            ),
            const SizedBox(height: 24),
            if (_hasControl && _isConnected) ...[
              Text(
                'Intensity: ${(_intensity * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Slider(
                value: _intensity,
                onChanged: _updateIntensity,
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _intensity = 0.0);
                    buttplug.stopVibration();
                  },
                  child: const Text('Stop'),
                ),
              ),
            ] else if (!_hasControl) ...[
              Center(
                child: Text(
                  'Control period has ended',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.check_circle : Icons.error,
          color: isActive ? Colors.green : Colors.red,
          size: 28,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: subtitle != null 
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isActive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ) 
          : null,
        trailing: isActive 
          ? const Icon(Icons.check, color: Colors.green)
          : const Icon(Icons.warning, color: Colors.red),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return 'Expired';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    parts.add('${seconds}s');
    
    return parts.join(' ');
  }
}
