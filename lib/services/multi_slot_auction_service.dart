import 'dart:async';
import 'dart:developer' as developer;
import '../models/auction.dart';
import '../models/device_control_slot.dart';
import '../models/operation_result.dart';
import '../services/web3_service.dart';
import '../utils/device_slot_identifier.dart';

/// An extension service that adds multi-slot capabilities to the Web3Service
/// without modifying the smart contract
class MultiSlotAuctionService {
  final Web3Service _web3Service;
  
  MultiSlotAuctionService(this._web3Service);
  
  /// Create a multi-slot auction
  Future<OperationResult> createMultiSlotAuction({
    required String sessionName,
    required DateTime startTime,
    required int slotDurationMinutes,
    required int slotCount,
    required double minimumBid,
  }) async {
    final sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
    
    _log('Creating multi-slot auction:');
    _log('  Session ID: $sessionId');
    _log('  Session Name: $sessionName');
    _log('  Start Time: $startTime');
    _log('  Slot Duration: $slotDurationMinutes minutes');
    _log('  Slot Count: $slotCount');
    _log('  Minimum Bid: $minimumBid ETH');
    
    try {
      // Calculate slot durations
      final List<DateTime> slotStartTimes = [];
      final int slotDurationHours = slotDurationMinutes ~/ 60;
      final int slotDurationRemainingMinutes = slotDurationMinutes % 60;
      
      // If we have remaining minutes, we need to round up to the nearest hour for compatibility
      final int adjustedSlotDurationHours = slotDurationRemainingMinutes > 0 
          ? slotDurationHours + 1 
          : slotDurationHours;
      
      _log('  Adjusted slot duration: $adjustedSlotDurationHours hours');
      
      // Create all the slots
      for (int i = 0; i < slotCount; i++) {
        final slotStartTime = startTime.add(Duration(minutes: i * slotDurationMinutes));
        slotStartTimes.add(slotStartTime);
        
        // Create unique slot ID that includes the session ID
        final slotId = '$sessionId-slot-$i';
        
        _log('Creating slot $i:');
        _log('  Slot ID: $slotId');
        _log('  Start Time: $slotStartTime');
        _log('  Duration: $adjustedSlotDurationHours hours');
        
        final result = await _web3Service.createAuction(
          deviceId: slotId,
          startTime: slotStartTime,
          duration: adjustedSlotDurationHours,
          minimumBid: minimumBid,
          isUserCreated: true,
        );
        
        if (!result.success) {
          _log('Failed to create slot: ${result.message}');
          return OperationResult(
            success: false,
            message: 'Failed to create slot $i: ${result.message}',
          );
        }
      }
      
      _log('✅ All $slotCount slots created successfully');
      
      // Debug: Get the IDs of all active auctions before refresh
      _log('Active auctions before refresh: ${_web3Service.activeAuctions.keys.join(', ')}');
      
      // Force refresh auctions after creating all slots
      await _web3Service.loadActiveAuctions(forceRefresh: true);

      // Debug: Get the IDs of all active auctions after refresh
      _log('Active auctions after refresh: ${_web3Service.activeAuctions.keys.join(', ')}');
      
      return OperationResult(
        success: true,
        message: 'Successfully created $slotCount auction slots',
      );
    } catch (e) {
      _log('❌ Error creating multi-slot auction: $e');
      return OperationResult(
        success: false,
        message: 'Error creating multi-slot auction: $e'
      );
    }
  }
  
  /// Place a bid on a specific auction slot
  Future<OperationResult> placeBidOnSlot({
    required String deviceId, 
    required DateTime slotStartTime,
    required double amount,
  }) async {
    final compositeId = DeviceSlotIdentifier.generateSlotDeviceId(deviceId, slotStartTime);
    _log('Placing bid on slot with composite ID: $compositeId, amount: $amount');
    
    final result = await _web3Service.placeBidNew(
      deviceId: compositeId,
      amount: amount,
    );
    
    return result;
  }
  
  /// Get all slots for a device
  Future<List<Auction>> getDeviceSlots(String deviceId) async {
    _log('Getting all slots for device: $deviceId');
    final allAuctions = _web3Service.activeAuctions.entries;
    
    // Filter auctions that are likely slots for this device
    // In a production system, you'd use a more reliable method to identify slots
    final slots = allAuctions
        .where((entry) => entry.key.contains(deviceId) ||
            entry.value['deviceId'].toString().contains(deviceId))
        .map((entry) => Auction.fromBlockchainData(entry.value))
        .toList();
    
    _log('Found ${slots.length} slots for device $deviceId');
    return slots;
  }
  
  /// Group all auctions by their base device ID
  Map<String, List<Auction>> groupAuctionsByDevice() {
    final List<Auction> allAuctions = _web3Service.activeAuctions.entries
        .map((entry) => Auction.fromBlockchainData(entry.value))
        .toList();
    
    final Map<String, List<Auction>> grouped = {};
    
    for (final auction in allAuctions) {
      final deviceInfo = DeviceSlotIdentifier.parseCompositeId(auction.deviceId);
      final baseDeviceId = deviceInfo['deviceId'] as String;
      
      if (!grouped.containsKey(baseDeviceId)) {
        grouped[baseDeviceId] = [];
      }
      
      grouped[baseDeviceId]!.add(auction);
    }
    
    // Sort each group's auctions by start time
    for (final deviceId in grouped.keys) {
      grouped[deviceId]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    
    return grouped;
  }
  
  /// Finalize an auction slot
  Future<OperationResult> finalizeSlot({
    required String deviceId,
    required DateTime slotStartTime,
  }) async {
    final compositeId = DeviceSlotIdentifier.generateSlotDeviceId(deviceId, slotStartTime);
    _log('Finalizing slot with composite ID: $compositeId');
    
    return await _web3Service.finalizeAuctionNew(deviceId: compositeId);
  }
  
  /// Convert slots to DeviceControlSlot objects for UI display
  List<DeviceControlSlot> convertToControlSlots(List<Auction> auctions) {
    return auctions.map((auction) => DeviceControlSlot(
      startTime: auction.startTime,
      endTime: auction.endTime,
      isAvailable: !auction.isFinalized,
    )).toList();
  }
  
  void _log(String message) {
    developer.log('MultiSlotAuctionService: $message');
  }
}
