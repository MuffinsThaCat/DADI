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

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    final buttplug = context.read<MockButtplugService>();
    try {
      if (!buttplug.isConnected) {
        await buttplug.connect();
      }
      await buttplug.connectToDevice(widget.deviceId);
      setState(() => _isConnected = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to device: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttplug = context.watch<MockButtplugService>();
    final remainingTime = widget.endTime.difference(DateTime.now());
    final hasControl = remainingTime.isNegative;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Device Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusIndicator('Connection', buttplug.isConnected),
                    const SizedBox(height: 8),
                    _buildStatusIndicator(
                      'Device',
                      buttplug.currentDevice != null,
                      subtitle: buttplug.currentDevice ?? 'Not connected',
                    ),
                    if (!hasControl) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Control expires in: ${_formatDuration(remainingTime)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Vibration Control',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.vibration),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _intensity,
                            onChanged: hasControl || !_isConnected
                                ? null
                                : (value) {
                                    setState(() => _intensity = value);
                                    buttplug.startVibration(value);
                                  },
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
                          onPressed: hasControl || !_isConnected
                              ? null
                              : () {
                                  setState(() => _intensity = 0.0);
                                  buttplug.stopVibration();
                                },
                          child: const Text('Stop'),
                        ),
                        ElevatedButton(
                          onPressed: hasControl || !_isConnected
                              ? null
                              : () {
                                  setState(() => _intensity = 0.5);
                                  buttplug.startVibration(0.5);
                                },
                          child: const Text('Medium'),
                        ),
                        ElevatedButton(
                          onPressed: hasControl || !_isConnected
                              ? null
                              : () {
                                  setState(() => _intensity = 1.0);
                                  buttplug.startVibration(1.0);
                                },
                          child: const Text('Max'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (buttplug.currentVibration > 0) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Device Feedback',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: buttplug.currentVibration,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Intensity: ${(buttplug.currentVibration * 100).round()}%',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
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
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.error,
          color: isActive ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
