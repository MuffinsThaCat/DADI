import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../services/mock_buttplug_service.dart';
import 'device_control_screen.dart';

class AuctionScreen extends StatefulWidget {
  final int initialTab;
  final String? deviceId;
  
  const AuctionScreen({
    super.key,
    this.initialTab = 0,
    this.deviceId,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateTime _startTime = DateTime.now().add(const Duration(minutes: 5));
  final Duration _duration = const Duration(minutes: 30);
  final String _minBid = '0.01';
  bool _isLoading = false;
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _minBidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimeController.text = _formatDateTime(_startTime);
    _durationController.text = _formatDuration(_duration);
    _minBidController.text = _minBid;
  }

  @override
  Widget build(BuildContext context) {
    final web3 = context.watch<Web3Service>();
    final buttplug = context.watch<MockButtplugService>();

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DADI Auctions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create Auction'),
              Tab(text: 'Active Auctions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCreateAuctionTab(web3, buttplug),
            _buildActiveAuctionsTab(web3),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAuctionTab(Web3Service web3, MockButtplugService buttplug) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Device',
                border: OutlineInputBorder(),
              ),
              value: buttplug.currentDevice,
              items: ['Mock Device 1', 'Mock Device 2', 'Mock Device 3']
                  .map((device) => DropdownMenuItem(
                        value: device,
                        child: Text(device),
                      ))
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                  await buttplug.connectToDevice(value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Minimum Bid (ETH)',
                border: OutlineInputBorder(),
              ),
              controller: _minBidController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a minimum bid';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        try {
                          final deviceId = buttplug.currentDevice;
                          if (deviceId == null) {
                            throw Exception('No device selected');
                          }

                          // Convert device ID to bytes32 by hashing it
                          final bytes = utf8.encode(deviceId);
                          final digest = sha256.convert(bytes);
                          final deviceIdBytes32 = '0x${digest.toString()}';
                          final minBidWei = BigInt.from(
                            (double.parse(_minBidController.text) * 1e18).toInt(),
                          );

                          // Ensure start time is at least 5 minutes in the future
                          final now = DateTime.now();
                          final minStartTime = now.add(const Duration(minutes: 5));
                          final startTime = _startTime.isBefore(minStartTime) ? minStartTime : _startTime;
                          final startTimeSeconds = startTime.millisecondsSinceEpoch ~/ 1000;

                          try {
                            await web3.createAuction(
                              deviceIdBytes32,
                              BigInt.from(startTimeSeconds),
                              BigInt.from(_duration.inSeconds),
                              minBidWei,
                            );
                          } catch (e) {
                            rethrow;
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Auction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAuctionsTab(Web3Service web3) {
    return ListView.builder(
      itemCount: web3.activeAuctions.length,
      itemBuilder: (context, index) {
        final deviceId = web3.activeAuctions.keys.elementAt(index);
        final auction = web3.activeAuctions[deviceId]!;
        final now = DateTime.now();
        final hasStarted = now.isAfter(auction['startTime'] as DateTime);
        final hasEnded = now.isAfter(auction['endTime'] as DateTime);
        final hasControl = auction['controller'] == web3.currentAddress;

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device ID: ${deviceId.substring(0, 10)}...'),
                Text('Owner: ${_formatAddress(auction['deviceOwner'] as String)}'),
                Text('Start Time: ${_formatDateTime(auction['startTime'] as DateTime)}'),
                Text('End Time: ${_formatDateTime(auction['endTime'] as DateTime)}'),
                Text('Minimum Bid: ${_formatEther(auction['minBid'] as BigInt)} ETH'),
                if (auction['highestBid'] != null && (auction['highestBid'] as BigInt) > BigInt.zero)
                  Text(
                    'Current Bid: ${_formatEther(auction['highestBid'] as BigInt)} ETH by ${_formatAddress(auction['highestBidder'] as String)}',
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (hasStarted && !hasEnded)
                      ElevatedButton(
                        onPressed: () => _showBidDialog(context, web3, deviceId, auction),
                        child: const Text('Place Bid'),
                      ),
                    if (hasEnded && auction['active'] as bool)
                      ElevatedButton(
                        onPressed: () => _finalizeAuction(web3, deviceId),
                        child: const Text('Finalize Auction'),
                      ),
                    if (hasControl)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeviceControlScreen(
                                deviceId: deviceId,
                                endTime: auction['endTime'] as DateTime,
                              ),
                            ),
                          );
                        },
                        child: const Text('Control Device'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBidDialog(
    BuildContext context,
    Web3Service web3,
    String deviceId,
    Map<String, dynamic> auction,
  ) async {
    String bidAmount = '';
    final currentBid = auction['highestBid'] as BigInt;
    final minBid = auction['minBid'] as BigInt;
    final minRequired = currentBid > BigInt.zero ? currentBid : minBid;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Highest Bid: ${_formatEther(currentBid)} ETH'),
            Text('Minimum Required: ${_formatEther(minRequired)} ETH'),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Bid Amount (ETH)',
                hintText: '0.1',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => bidAmount = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final amount = BigInt.from(
                  double.parse(bidAmount) * 1e18,
                );
                if (amount <= minRequired) {
                  throw Exception('Bid too low');
                }
                await web3.placeBid(deviceId, amount);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeAuction(Web3Service web3, String deviceId) async {
    try {
      setState(() => _isLoading = true);
      await web3.finalizeAuction(deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auction finalized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatAddress(String address) {
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes % 60}';
  }

  String _formatEther(BigInt wei) {
    return (wei / BigInt.from(1e18)).toStringAsFixed(4);
  }
}

class _DurationPicker extends StatefulWidget {
  final Duration initialDuration;

  const _DurationPicker({required this.initialDuration});

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours;
    _minutes = widget.initialDuration.inMinutes % 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _hours.toString()),
                  onChanged: (value) {
                    setState(() {
                      _hours = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _minutes.toString()),
                  onChanged: (value) {
                    setState(() {
                      _minutes = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              Duration(hours: _hours, minutes: _minutes),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
