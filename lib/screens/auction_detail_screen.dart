import 'package:flutter/material.dart';
import '../models/auction.dart';
import '../models/device_control_slot.dart';
import '../models/auction_status.dart';
import '../models/operation_result.dart';
import '../services/web3_service.dart';
import '../services/multi_slot_auction_service.dart';
import '../widgets/time_slot_selector.dart';
import '../widgets/slot_duration_selector.dart';
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
  int _slotDurationMinutes = 2; // Default to 2 minutes

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
    // Create control slots based on the auction time range and selected duration
    final List<DeviceControlSlot> slots = [];
    
    // Get the total auction duration in minutes
    final totalDurationMinutes = _auction.endTime.difference(_auction.startTime).inMinutes;
    
    // Calculate number of slots based on the selected duration
    final int numberOfSlots = totalDurationMinutes ~/ _slotDurationMinutes;
    
    // Create slots with equal duration
    DateTime slotStart = _auction.startTime;
    for (int i = 0; i < numberOfSlots; i++) {
      final slotEnd = slotStart.add(Duration(minutes: _slotDurationMinutes));
      
      slots.add(DeviceControlSlot(
        startTime: slotStart,
        endTime: slotEnd,
        isAvailable: true,
      ));
      
      slotStart = slotEnd;
    }
    
    // If there's any remaining time that doesn't fit evenly, add a final shorter slot
    if (slotStart.isBefore(_auction.endTime)) {
      slots.add(DeviceControlSlot(
        startTime: slotStart,
        endTime: _auction.endTime,
        isAvailable: true,
      ));
    }
    
    setState(() {
      _controlSlots = slots;
      _selectedTimeSlot = null; // Reset selected slot when regenerating
    });
  }

  void _onDurationSelected(int duration) {
    setState(() {
      _slotDurationMinutes = duration;
    });
    _generateControlSlots(); // Regenerate slots with the new duration
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
    
    // For non-mock mode, we require a time slot selection
    if (_selectedTimeSlot == null && !widget.web3Service.isMockMode) {
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
      OperationResult<dynamic> result;
      
      // If a time slot is selected, we'll use the slot's start time for bidding
      // Otherwise, we'll use the auction's device ID directly
      if (_selectedTimeSlot != null) {
        // Create the multi-slot service
        final multiSlotService = MultiSlotAuctionService(widget.web3Service);
        
        result = await multiSlotService.placeBidOnSlot(
          deviceId: _auction.deviceId.split('-slot-').first, // Extract base device ID
          slotStartTime: _selectedTimeSlot!.startTime,
          amount: bidAmount
        );
      } else {
        // Use regular bidding for the entire auction period
        result = await widget.web3Service.placeBidNew(
          deviceId: _auction.deviceId,
          amount: bidAmount
        );
      }
      
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

  Future<void> _placeMockBid() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Placing mock bid...';
      _showStatusMessage = true;
    });
    
    try {
      final result = await widget.web3Service.placeMockBid(_auction.deviceId);
      
      if (result.success) {
        // Refresh auction data after placing bid
        await _refreshAuctionData();
        
        setState(() {
          _statusMessage = 'Mock bid placed successfully!';
          _showStatusMessage = true;
          _isLoading = false;
        });
        
        if (widget.onAuctionUpdated != null) {
          widget.onAuctionUpdated!();
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error placing mock bid: ${result.message}';
          _showStatusMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error placing mock bid: $e';
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
    final bool canBid = _auction.status == AuctionStatus.active;
    final bool canFinalize = _auction.status == AuctionStatus.ended || 
                          (DateTime.now().isAfter(_auction.endTime) && _auction.status == AuctionStatus.active);
    final bool canCancel = _auction.status == AuctionStatus.active && 
                        _auction.highestBidder.isEmpty;
    final bool isMockMode = widget.web3Service.isMockMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Details'),
        actions: [
          if (isMockMode)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: const Chip(
                label: Text('MOCK MODE'),
                backgroundColor: Colors.orange,
                labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
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
                              _auction.status == AuctionStatus.active ? Icons.check_circle : Icons.cancel,
                              color: _auction.status == AuctionStatus.active ? Colors.green : 
                                     _auction.status == AuctionStatus.ended ? Colors.orange : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _auction.status == AuctionStatus.active ? 'Active and Not Finalized' : 
                              _auction.status == AuctionStatus.ended ? 'Ended' : 
                              _auction.status == AuctionStatus.finalized ? 'Finalized' : 'Cancelled',
                              style: TextStyle(
                                color: _auction.status == AuctionStatus.active ? Colors.green : 
                                       _auction.status == AuctionStatus.ended ? Colors.orange : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                
                // Slot duration selector
                if (canBid)
                  SlotDurationSelector(
                    onDurationSelected: _onDurationSelected,
                    selectedDuration: _slotDurationMinutes,
                    totalDurationMinutes: _auction.endTime.difference(_auction.startTime).inMinutes,
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
                          
                          // Add mock bid button in mock mode
                          if (isMockMode && canBid)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _placeMockBid,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12.0),
                                    child: Text('Place Random Mock Bid', style: TextStyle(color: Colors.orange)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                
                // Finalize auction button (for owner)
                if (canFinalize || (isMockMode && canBid))
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finalizeAuction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(isMockMode ? 'Finalize Mock Auction' : 'Finalize Auction'),
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
