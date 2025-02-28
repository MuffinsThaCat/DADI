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
    final isConnected = web3.isConnected;
    final isMockMode = web3.isMockMode;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DADI Auctions'),
          actions: [
            // Network status indicator
            Tooltip(
              message: isMockMode 
                  ? 'Running in mock mode (no blockchain)' 
                  : isConnected 
                      ? 'Connected to blockchain' 
                      : 'Not connected to blockchain',
              child: IconButton(
                icon: Icon(
                  isMockMode 
                      ? Icons.cloud_off 
                      : isConnected 
                          ? Icons.cloud_done 
                          : Icons.cloud_off,
                  color: isMockMode 
                      ? Colors.orange 
                      : isConnected 
                          ? Colors.green 
                          : Colors.red,
                ),
                onPressed: _showNetworkStatus,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshAuctions,
              tooltip: 'Refresh auctions',
            ),
          ],
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });

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
                          bool isValid = await web3.testContract();
                          if (!isValid) {
                            _errorMessage = 'Contract validation failed. Please check your connection and try again.';
                            _isLoading = false;
                            if (mounted) {
                              setState(() {});
                            }
                            return;
                          }
                          
                          final deviceId = buttplug.currentDevice;
                          if (deviceId == null) {
                            throw Exception('No device selected');
                          }

                          // Convert form values to appropriate types
                          final minBidEth = double.parse(_minBidController.text);
                          
                          _log('Creating auction with params:');
                          _log('Device ID: $deviceId');
                          _log('Start Date: $_startDate');
                          _log('End Date: $_endDate');
                          _log('Min Bid: $minBidEth ETH');
                          
                          // Call the contract method
                          try {
                            await web3.createAuction(
                              deviceId: deviceId,
                              startTime: _startDate,
                              duration: _endDate.difference(_startDate),
                              minimumBid: minBidEth,
                            );
                            
                            if (mounted) {
                              // Check if we've switched to mock mode during the process
                              if (web3.isMockMode) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Created mock auction due to blockchain connection issues'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Auction created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              String errorMsg = e.toString();
                              if (errorMsg.startsWith('Exception: ')) {
                                errorMsg = errorMsg.substring('Exception: '.length);
                              }
                              if (errorMsg.contains('insufficient funds')) {
                                errorMsg = 'Insufficient funds in your wallet to create this auction';
                              } else if (errorMsg.contains('user rejected')) {
                                errorMsg = 'Transaction was rejected in your wallet';
                              } else if (errorMsg.contains('Internal JSON-RPC error')) {
                                errorMsg = 'Blockchain connection error. Switched to mock mode.';
                              } else if (errorMsg.contains('execution reverted')) {
                                final revertMatch = RegExp(r'reverted: (.+?)(?:,|$)').firstMatch(errorMsg);
                                if (revertMatch != null) {
                                  errorMsg = 'Smart contract error: ${revertMatch.group(1)}';
                                } else {
                                  errorMsg = 'Smart contract rejected the transaction';
                                }
                              }
                              _errorMessage = errorMsg;
                            });

                            // Store context in a local variable to avoid using it across async gaps
                            final currentContext = context;
                            if (mounted) {
                              ScaffoldMessenger.of(currentContext).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $_errorMessage'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: 'Details',
                                    onPressed: () {
                                      // Use the stored context here
                                      showDialog(
                                        context: currentContext,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Error Details'),
                                          content: SingleChildScrollView(
                                            child: Text(e.toString()),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogContext),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
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
              
              // Skip if auction data is invalid
              if (auction['endTime'] == null) {
                return const SizedBox.shrink();
              }
              
              final now = DateTime.now();
              final endTimeBigInt = auction['endTime'] as BigInt;
              final endTime = DateTime.fromMillisecondsSinceEpoch(
                (endTimeBigInt.toInt() * 1000)
              );
              final hasEnded = now.isAfter(endTime);
              final isActive = auction['active'] as bool? ?? false;
              final isFinalized = auction['finalized'] as bool? ?? false;
              final hasControl = auction['highestBidder'] == web3.currentAddress;
              final owner = auction['owner'];  
              final highestBid = auction['highestBid'] as BigInt;
              final highestBidder = auction['highestBidder'];
              final minBid = auction['minBid'] as BigInt? ?? BigInt.zero;

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
                      const SizedBox(height: 8),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.green.shade100 
                              : (isFinalized ? Colors.blue.shade100 : Colors.orange.shade100),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive 
                              ? 'Active' 
                              : (isFinalized ? 'Finalized' : 'Ended'),
                          style: TextStyle(
                            color: isActive 
                                ? Colors.green.shade800 
                                : (isFinalized ? Colors.blue.shade800 : Colors.orange.shade800),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isActive && !hasEnded)
                            ElevatedButton(
                              onPressed: () => _showBidDialog(context, web3, deviceId, auction),
                              child: const Text('Place Bid'),
                            ),
                          if (hasEnded && !isFinalized)
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
    final highestBid = auction['highestBid'] as BigInt;
    final minRequired = highestBid > BigInt.zero 
        ? highestBid + BigInt.one // Minimum increment of 1 wei
        : auction['minBid'] as BigInt? ?? BigInt.zero;
    
    // Convert wei to ETH for display
    final minRequiredEth = minRequired.toDouble() / 1e18;
    
    final amount = await _showBidDialogNew(context, minRequiredEth);
    
    if (amount == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await web3.placeBidNew(
        deviceId: deviceId,
        amount: amount,
      );
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bid placed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the auction data
          web3.loadActiveAuctions();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _finalizeAuction(Web3Service web3, String deviceId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await web3.finalizeAuctionNew(
        deviceId: deviceId,
      );
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Auction finalized successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to device control screen if auction was finalized
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
          } else {
            web3.loadActiveAuctions();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
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

  void _log(String message) {
    developer.log('AuctionScreen: $message');
  }

  void _showNetworkStatus() async {
    final web3Service = context.read<Web3Service>();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Checking Network Status'),
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    
    try {
      // Get network status
      final status = await web3Service.checkNetworkStatus();
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Format the status information for display
      final formattedStatus = StringBuffer();
      formattedStatus.writeln('📊 Blockchain Status Report:');
      formattedStatus.writeln('');
      
      // Connection status
      final bool connected = status['connected'] ?? false;
      final bool mockMode = status['mockMode'] ?? false;
      
      if (mockMode) {
        formattedStatus.writeln('🔶 Running in MOCK MODE (no blockchain)');
        formattedStatus.writeln('');
      } else if (connected) {
        formattedStatus.writeln('✅ Connected to blockchain');
      } else {
        formattedStatus.writeln('❌ Not connected to blockchain');
        if (status['error'] != null) {
          formattedStatus.writeln('Error: ${status['error']}');
        }
        formattedStatus.writeln('');
      }
      
      // Network information
      if (status['networkName'] != null) {
        formattedStatus.writeln('🌐 Network: ${status['networkName']} (Chain ID: ${status['chainId']})');
      }
      
      // Account information
      if (status['account'] != null) {
        final account = status['account'] as String;
        final shortAccount = '${account.substring(0, 6)}...${account.substring(account.length - 4)}';
        formattedStatus.writeln('👤 Account: $shortAccount');
      }
      
      // Contract information
      if (status['contractAddress'] != null) {
        final contractAddress = status['contractAddress'] as String;
        final shortContract = '${contractAddress.substring(0, 6)}...${contractAddress.substring(contractAddress.length - 4)}';
        formattedStatus.writeln('📝 Contract: $shortContract');
        
        if (status['contractResponsive'] == true) {
          formattedStatus.writeln('✅ Contract is responsive');
          formattedStatus.writeln('📊 Auction Count: ${status['auctionCount']}');
        } else {
          formattedStatus.writeln('❌ Contract is not responsive');
          if (status['contractError'] != null) {
            formattedStatus.writeln('Error: ${status['contractError']}');
          }
        }
      }
      
      // Gas price
      if (status['gasPrice'] != null) {
        formattedStatus.writeln('⛽ Gas Price: ${status['gasPrice']} wei');
      }
      
      // Block number
      if (status['blockNumber'] != null) {
        formattedStatus.writeln('🧱 Block Number: ${status['blockNumber']}');
      }
      
      // Show the status dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Network Status'),
            content: SingleChildScrollView(
              child: Text(formattedStatus.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  web3Service.toggleMockMode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        web3Service.isMockMode
                            ? 'Switched to mock mode'
                            : 'Switched to blockchain mode',
                      ),
                      backgroundColor: web3Service.isMockMode ? Colors.orange : Colors.blue,
                    ),
                  );
                  _refreshAuctions();
                },
                child: Text(
                  web3Service.isMockMode
                      ? 'Try Real Blockchain'
                      : 'Switch to Mock Mode',
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to check network status: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _refreshAuctions() {
    final web3Service = context.read<Web3Service>();
    web3Service.loadActiveAuctions();
  }

  Future<double?> _showBidDialogNew(BuildContext context, [double minBid = 0.1]) async {
    double? bidAmount;
    
    return showDialog<double?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Place a Bid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter bid amount in ETH (minimum ${minBid + 0.01} ETH):'),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g., ${(minBid + 0.01).toStringAsFixed(2)}',
                ),
                onChanged: (value) {
                  try {
                    bidAmount = double.parse(value);
                  } catch (_) {
                    bidAmount = null;
                  }
                },
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
                if (bidAmount != null && bidAmount! > minBid) {
                  Navigator.pop(context, bidAmount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid amount greater than $minBid ETH'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
