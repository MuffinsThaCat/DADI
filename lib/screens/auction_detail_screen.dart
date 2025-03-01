import 'package:flutter/material.dart';
import '../models/auction.dart';
import '../models/device_control_slot.dart';
import '../services/web3_service.dart';
import '../widgets/time_slot_selector.dart';
import 'dart:async';

class AuctionDetailScreen extends StatefulWidget {
  final Auction auction;
  final Web3Service web3Service;
  final VoidCallback? onAuctionUpdated;

  const AuctionDetailScreen({
    Key? key,
    required this.auction,
    required this.web3Service,
    this.onAuctionUpdated,
  }) : super(key: key);

  @override
  AuctionDetailScreenState createState() => AuctionDetailScreenState();
}

class AuctionDetailScreenState extends State<AuctionDetailScreen> {
  late Auction _auction;
  final TextEditingController _bidAmountController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _showStatusMessage = false;
  DeviceControlSlot? _selectedTimeSlot;
  List<DeviceControlSlot> _controlSlots = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _auction = widget.auction;
    
    // Generate control slots based on auction time range
    _generateControlSlots();
    
    // Set up a timer to refresh the auction data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshAuctionData();
    });
    
    // Initial refresh
    _refreshAuctionData();
  }

  void _generateControlSlots() {
    // For now, we'll create mock control slots
    // In a real implementation, these would come from the auction data
    final List<DeviceControlSlot> slots = [];
    
    // Create slots in 30-minute increments within the auction time range
    DateTime slotStart = _auction.startTime;
    while (slotStart.isBefore(_auction.endTime)) {
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      if (slotEnd.isAfter(_auction.endTime)) {
        break;
      }
      
      slots.add(DeviceControlSlot(
        startTime: slotStart,
        endTime: slotEnd,
        isAvailable: true,
      ));
      
      slotStart = slotEnd;
    }
    
    setState(() {
      _controlSlots = slots;
    });
  }

  Future<void> _refreshAuctionData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final result = await widget.web3Service.getAuction(deviceId: _auction.deviceId);
      if (result.success && result.data != null) {
        if (mounted) {
          setState(() {
            _auction = result.data!;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error refreshing auction: $e';
          _showStatusMessage = true;
        });
      }
    }
  }

  Future<void> _placeBid() async {
    if (_bidAmountController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a bid amount';
        _showStatusMessage = true;
      });
      return;
    }
    
    final double bidAmount = double.tryParse(_bidAmountController.text) ?? 0;
    if (bidAmount <= 0) {
      setState(() {
        _statusMessage = 'Bid amount must be greater than 0';
        _showStatusMessage = true;
      });
      return;
    }
    
    if (bidAmount <= _auction.highestBid) {
      setState(() {
        _statusMessage = 'Bid amount must be greater than current highest bid';
        _showStatusMessage = true;
      });
      return;
    }
    
    if (_selectedTimeSlot == null) {
      setState(() {
        _statusMessage = 'Please select a time slot';
        _showStatusMessage = true;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Placing bid...';
      _showStatusMessage = true;
    });
    
    try {
      final result = await widget.web3Service.placeBidNew(
        deviceId: _auction.deviceId,
        amount: bidAmount
      );
      
      if (result.success) {
        // Refresh auction data after placing bid
        await _refreshAuctionData();
        
        setState(() {
          _statusMessage = 'Bid placed successfully!';
          _showStatusMessage = true;
          _bidAmountController.clear();
          _isLoading = false;
        });
        
        if (widget.onAuctionUpdated != null) {
          widget.onAuctionUpdated!();
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error placing bid: ${result.message}';
          _showStatusMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error placing bid: $e';
        _showStatusMessage = true;
      });
    }
  }

  Future<void> _finalizeAuction() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Finalizing auction...';
      _showStatusMessage = true;
    });
    
    try {
      final result = await widget.web3Service.finalizeAuctionNew(
        deviceId: _auction.deviceId
      );
      
      if (result.success) {
        // Refresh auction data after finalizing
        await _refreshAuctionData();
        
        setState(() {
          _statusMessage = 'Auction finalized successfully!';
          _showStatusMessage = true;
          _isLoading = false;
        });
        
        if (widget.onAuctionUpdated != null) {
          widget.onAuctionUpdated!();
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error finalizing auction: ${result.message}';
          _showStatusMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error finalizing auction: $e';
        _showStatusMessage = true;
      });
    }
  }

  Future<void> _cancelAuction() async {
    // Show confirmation dialog
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Auction'),
        content: const Text('Are you sure you want to cancel this auction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cancelling auction...';
      _showStatusMessage = true;
    });
    
    try {
      final result = await widget.web3Service.cancelAuction(
        deviceId: _auction.deviceId
      );
      
      if (result.success) {
        // Refresh auction data after cancelling
        await _refreshAuctionData();
        
        setState(() {
          _statusMessage = 'Auction cancelled successfully!';
          _showStatusMessage = true;
          _isLoading = false;
        });
        
        if (widget.onAuctionUpdated != null) {
          widget.onAuctionUpdated!();
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error cancelling auction: ${result.message}';
          _showStatusMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error cancelling auction: $e';
        _showStatusMessage = true;
      });
    }
  }

  @override
  void dispose() {
    _bidAmountController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = _auction.owner.toLowerCase() == widget.web3Service.currentAddress?.toLowerCase();
    final bool canFinalize = isOwner && 
                            _auction.isActive && 
                            DateTime.now().isAfter(_auction.endTime);
    final bool canBid = !isOwner && 
                       _auction.isActive && 
                       DateTime.now().isBefore(_auction.endTime);
    final bool canCancel = isOwner && 
                          _auction.isActive && 
                          _auction.highestBid == 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Details'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auction details card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device ID: ${_auction.deviceId}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Owner: ${_auction.owner}'),
                        const SizedBox(height: 8),
                        Text('Start Time: ${_auction.startTime.toString()}'),
                        const SizedBox(height: 8),
                        Text('End Time: ${_auction.endTime.toString()}'),
                        const SizedBox(height: 8),
                        Text('Minimum Bid: ${_auction.minimumBid} ETH'),
                        const SizedBox(height: 8),
                        Text(
                          'Highest Bid: ${_auction.highestBid} ETH',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_auction.highestBidder.isNotEmpty && _auction.highestBidder != '0x0000000000000000000000000000000000000000')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Highest Bidder: ${_auction.highestBidder}'),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              _auction.isActive ? Icons.check_circle : Icons.cancel,
                              color: _auction.isActive ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _auction.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: _auction.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _auction.isFinalized ? Icons.check_circle : Icons.pending,
                              color: _auction.isFinalized ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _auction.isFinalized ? 'Finalized' : 'Not Finalized',
                              style: TextStyle(
                                color: _auction.isFinalized ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Time slot selector
                if (canBid)
                  TimeSlotSelector(
                    slots: _controlSlots,
                    onSlotSelected: (slot) {
                      setState(() {
                        _selectedTimeSlot = slot;
                      });
                    },
                    selectedSlot: _selectedTimeSlot,
                  ),
                
                const SizedBox(height: 24),
                
                // Bid form
                if (canBid)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Place a Bid',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _bidAmountController,
                            decoration: InputDecoration(
                              labelText: 'Bid Amount (ETH)',
                              hintText: 'Enter amount greater than ${_auction.highestBid} ETH',
                              border: const OutlineInputBorder(),
                              suffixText: 'ETH',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _placeBid,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Text('Place Bid'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Finalize auction button (for owner)
                if (canFinalize)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finalizeAuction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Finalize Auction'),
                        ),
                      ),
                    ),
                  ),
                
                // Cancel auction button (for owner with no bids)
                if (canCancel)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelAuction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Cancel Auction'),
                        ),
                      ),
                    ),
                  ),
                
                // Status message
                if (_showStatusMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Card(
                      color: _statusMessage.contains('Error') 
                          ? Colors.red.shade100 
                          : Colors.green.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              _statusMessage.contains('Error') 
                                  ? Icons.error 
                                  : Icons.check_circle,
                              color: _statusMessage.contains('Error') 
                                  ? Colors.red 
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_statusMessage),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _showStatusMessage = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
