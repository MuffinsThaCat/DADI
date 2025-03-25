import 'dart:async';
import 'package:flutter/material.dart';
import '../models/auction.dart';
import '../screens/device_control_screen.dart';

class DeviceControlNotification extends StatefulWidget {
  final Auction auction;
  final String userAddress;

  const DeviceControlNotification({
    Key? key,
    required this.auction,
    required this.userAddress,
  }) : super(key: key);

  @override
  State<DeviceControlNotification> createState() => _DeviceControlNotificationState();
}

class _DeviceControlNotificationState extends State<DeviceControlNotification> {
  late Timer _refreshTimer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.auction.getRemainingControlTime();
    
    // Update the countdown every second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remainingTime = widget.auction.getRemainingControlTime();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Don't show the notification if the control period is over
    if (_remainingTime.inSeconds <= 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: Colors.green.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Device Ready for Control!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You have won the auction for device ${widget.auction.deviceId}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining control time: ${_formatDuration(_remainingTime)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DeviceControlScreen(
                        deviceId: widget.auction.deviceId,
                        endTime: widget.auction.endTime,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                icon: const Icon(Icons.touch_app),
                label: const Text('Control Now', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
