import 'dart:developer' as developer;
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
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 24));
  bool _isLoading = false;
  String? _errorMessage;
  bool _isConnected = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _minBidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDateController.text = _formatDateTime(_startDate);
    _endDateController.text = _formatDateTime(_endDate);
    _minBidController.text = '0.01';
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _minBidController.dispose();
    super.dispose();
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
              controller: _startDateController,
              decoration: const InputDecoration(
                labelText: 'Start Date',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a start date';
                }
                try {
                  DateTime.parse(value);
                  return null;
                } catch (e) {
                  return 'Invalid date format';
                }
              },
              onChanged: (value) {
                try {
                  _startDate = DateTime.parse(value);
                } catch (e) {
                  // Invalid date format, ignore
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _endDateController,
              decoration: const InputDecoration(
                labelText: 'End Date',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an end date';
                }
                try {
                  final endDate = DateTime.parse(value);
                  if (endDate.isBefore(_startDate)) {
                    return 'End date must be after start date';
                  }
                  return null;
                } catch (e) {
                  return 'Invalid date format';
                }
              },
              onChanged: (value) {
                try {
                  _endDate = DateTime.parse(value);
                } catch (e) {
                  // Invalid date format, ignore
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
                          // Check if web3 is connected
                          if (!web3.isConnected) {
                            throw Exception('Wallet not connected. Please connect your wallet first.');
                          }
                          
                          // Check if contract is initialized
                          if (!web3.isContractInitialized) {
                            await web3.initializeContract();
                            if (!web3.isContractInitialized) {
                              throw Exception('Failed to initialize contract. Please try again.');
                            }
                          }
                          
                          // Validate contract with a test call
                          final isValid = await web3.testContract();
                          if (!isValid) {
                            throw Exception('Contract validation failed. Please check your connection and try again.');
                          }
                          
                          final deviceId = buttplug.currentDevice;
                          if (deviceId == null) {
                            throw Exception('No device selected');
                          }

                          // Convert form values to appropriate types
                          final minBidEth = double.parse(_minBidController.text);
                          
                          // Convert ETH to wei (1 ETH = 10^18 wei)
                          final minBidWei = _toWei(minBidEth);
                          
                          _log('Creating auction with params:');
                          _log('Device ID: $deviceId');
                          _log('Start Date: $_startDate');
                          _log('End Date: $_endDate');
                          _log('Min Bid: $minBidEth ETH ($minBidWei wei)');
                          
                          // Call the contract method
                          await web3.createAuction(
                            deviceId,
                            _startDate,
                            _endDate,
                            minBidWei,
                          );
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Auction created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
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
    if (!web3.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Connect your wallet to view auctions'),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _connectWallet,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Connect Wallet'),
            ),
          ],
        ),
      );
    }
    
    return FutureBuilder(
      future: web3.loadActiveAuctions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ListView.builder(
            itemCount: web3.activeAuctions.length,
            itemBuilder: (context, index) {
              final deviceId = web3.activeAuctions.keys.elementAt(index);
              final auction = web3.activeAuctions[deviceId]!;
              
              // Skip inactive auctions
              if (auction['endTime'] == null) {
                return const SizedBox.shrink();
              }
              
              final now = DateTime.now();
              final endTimeBigInt = auction['endTime'] as BigInt;
              final endTime = DateTime.fromMillisecondsSinceEpoch(
                (endTimeBigInt.toInt() * 1000)
              );
              final hasEnded = now.isAfter(endTime);
              final hasControl = auction['highestBidder'] == web3.currentAddress;
              final owner = auction['owner'];  
              final highestBid = auction['highestBid'] as BigInt;
              final highestBidder = auction['highestBidder'];
              final minBid = auction['minBid'] as BigInt;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device ID: ${deviceId.substring(0, 10)}...'),
                      Text('Owner: ${_formatAddress(owner)}'),
                      Text('End Time: ${_formatDateTime(endTime)}'),
                      Text('Minimum Bid: ${_formatEther(minBid)} ETH'),
                      if (highestBid > BigInt.zero && highestBidder != null)
                        Text(
                          'Current Bid: ${_formatEther(highestBid)} ETH by ${_formatAddress(highestBidder)}',
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!hasEnded)
                            ElevatedButton(
                              onPressed: () => _showBidDialog(context, web3, deviceId, auction),
                              child: const Text('Place Bid'),
                            ),
                          if (hasEnded && !auction['finalized'])
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
                                      endTime: endTime,
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
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final web3 = Provider.of<Web3Service>(context, listen: false);
      await web3.connect();
      
      // Give it a moment to connect before trying to initialize
      await Future.delayed(const Duration(seconds: 1));
      
      // Manually initialize contract and load auctions
      try {
        await web3.initializeContract();
        await web3.loadActiveAuctions();
      } catch (e) {
        developer.log('Contract initialization error: $e');
        // Continue anyway - we're at least connected
      }
      
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
      await web3.finalizeAuction(deviceId);
      
      if (mounted) {
        final auction = web3.activeAuctions[deviceId];
        if (auction != null) {
          final endTimeBigInt = auction['endTime'] as BigInt;
          final endTime = DateTime.fromMillisecondsSinceEpoch(
            (endTimeBigInt.toInt() * 1000)
          );
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DeviceControlScreen(
                deviceId: deviceId,
                endTime: endTime,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatAddress(String address) {
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatEther(BigInt wei) {
    final ethValue = wei.toDouble() / 1e18;
    return ethValue.toStringAsFixed(4);
  }

  BigInt _toWei(double eth) {
    return BigInt.from(eth * 1e18);
  }

  void _log(String message) {
    developer.log('AuctionScreen: $message');
  }
}
