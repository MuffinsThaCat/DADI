import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_connector_interface.dart';
import '../widgets/wavy_background.dart';

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

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    
    // Initialize pulse animation for the intensity indicator
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Start timer to check control period
    _controlTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Check if control period has expired
          if (DateTime.now().isAfter(widget.endTime) && _intensity > 0) {
            _intensity = 0;
            final deviceConnector = context.read<DeviceConnectorInterface>();
            deviceConnector.stopVibration();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    _pulseAnimation.dispose();
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    final deviceConnector = context.read<DeviceConnectorInterface>();
    try {
      if (!deviceConnector.isConnected) {
        await deviceConnector.connect();
      }
      setState(() {
        _isConnected = deviceConnector.isConnected;
        _currentDeviceId = deviceConnector.currentDevice;
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
    final deviceConnector = context.read<DeviceConnectorInterface>();
    if (value > 0) {
      deviceConnector.startVibration(value);
    } else {
      deviceConnector.stopVibration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceConnector = context.watch<DeviceConnectorInterface>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Device Control',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
      ),
      body: WavyBackground(
        primaryColor: theme.colorScheme.primary.withOpacity(0.7),
        secondaryColor: theme.colorScheme.secondary.withOpacity(0.7),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device and control status
                _buildStatusSection(),
                
                const SizedBox(height: 24),
                
                // Control interface
                _buildControlInterface(theme),
                
                const SizedBox(height: 20),
                
                // Control buttons
                if (_hasControl && _isConnected) 
                  _buildControlButtons(deviceConnector),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusSection() {
    final remainingTime = widget.endTime.difference(DateTime.now());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        
        // Connection status card
        _buildStatusCard(
          icon: _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          title: 'Device Connection',
          isActive: _isConnected,
          subtitle: _currentDeviceId != null ? 'Connected to: ${_currentDeviceId!}' : 'Not connected',
        ),
        
        // Remaining time card
        _buildStatusCard(
          icon: _hasControl ? Icons.timer : Icons.timer_off,
          title: 'Control Period',
          isActive: _hasControl,
          subtitle: _hasControl 
            ? 'Time remaining: ${_formatDuration(remainingTime)}'
            : 'Control period has ended',
          showProgressBar: _hasControl,
          progressValue: _hasControl 
            ? remainingTime.inSeconds / (widget.endTime.difference(DateTime.now().subtract(const Duration(minutes: 30)))).inSeconds
            : 0,
        ),
      ],
    );
  }
  
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required bool isActive,
    required String subtitle,
    bool showProgressBar = false,
    double progressValue = 0,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isActive 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isActive 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive 
                      ? theme.colorScheme.primary.withOpacity(0.2) 
                      : theme.colorScheme.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isActive 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (showProgressBar) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlInterface(ThemeData theme) {
    if (!_hasControl || !_isConnected) {
      return _buildControlDisabledMessage();
    }
    
    final int intensityPercentage = (_intensity * 100).round();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Intensity Control',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Intensity circle indicator
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(_intensity * 0.5),
                        blurRadius: 20 + (_pulseAnimation.value * 30 * _intensity),
                        spreadRadius: 5 + (_pulseAnimation.value * 10 * _intensity),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$intensityPercentage%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }
            ),
            
            const SizedBox(height: 30),
            
            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
                thumbColor: theme.colorScheme.primary,
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 20,
                ),
              ),
              child: Slider(
                value: _intensity,
                onChanged: _updateIntensity,
                divisions: 20,
                label: '$intensityPercentage%',
              ),
            ),
            
            // Intensity labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Low',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Medium',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'High',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlDisabledMessage() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 30.0,
        ),
        child: Column(
          children: [
            Icon(
              _isConnected 
                ? Icons.access_time_filled 
                : Icons.bluetooth_disabled,
              size: 60,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              !_isConnected 
                ? 'Device Not Connected' 
                : 'Control Period Has Ended',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              !_isConnected 
                ? 'Please connect your device to enable control features' 
                : 'Your control period for this device has ended',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: !_isConnected ? _connectToDevice : null,
              icon: Icon(
                !_isConnected 
                  ? Icons.bluetooth_searching
                  : Icons.timelapse,
              ),
              label: Text(
                !_isConnected 
                  ? 'Connect Device'
                  : 'Control Expired',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButtons(DeviceConnectorInterface deviceConnector) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          label: 'Stop',
          icon: Icons.stop_circle_outlined,
          onPressed: () {
            setState(() => _intensity = 0.0);
            deviceConnector.stopVibration();
          },
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 16),
        _buildControlButton(
          label: '50%',
          icon: Icons.wifi_tethering,
          onPressed: () {
            setState(() => _intensity = 0.5);
            deviceConnector.startVibration(0.5);
          },
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 16),
        _buildControlButton(
          label: 'Max',
          icon: Icons.power,
          onPressed: () {
            setState(() => _intensity = 1.0);
            deviceConnector.startVibration(1.0);
          },
          color: Colors.purple,
        ),
      ],
    );
  }
  
  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
