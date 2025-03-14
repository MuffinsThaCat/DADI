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
  
  /// Create an auction with multiple time slots
  Future<OperationResult<List<Auction>>> createMultiSlotAuction({
    required String deviceId,
    required DateTime startTime,
    required int slotDurationMinutes,
    required int numSlots, 
    required double minimumBid,
  }) async {
    final List<Auction> createdAuctions = [];
    final List<String> errors = [];
    
    _log('Creating multi-slot auction for device: $deviceId, slots: $numSlots, duration: $slotDurationMinutes minutes');
    
    for (int i = 0; i < numSlots; i++) {
      final slotStartTime = startTime.add(Duration(minutes: i * slotDurationMinutes));
      final slotEndTime = slotStartTime.add(Duration(minutes: slotDurationMinutes));
      
      // Generate a unique ID for this slot
      final slotId = "$deviceId-slot-$i";
      final compositeId = DeviceSlotIdentifier.generateSlotDeviceId(deviceId, slotStartTime);
      
      _log('Creating slot $i: $slotId, composite ID: $compositeId, time: $slotStartTime - $slotEndTime');
      
      try {
        final result = await _web3Service.createAuction(
          deviceId: compositeId,
          startTime: slotStartTime,
          duration: Duration(minutes: slotDurationMinutes),
          minimumBid: minimumBid,
        );
        
        if (result.success && result.data != null) {
          createdAuctions.add(result.data!);
        } else {
          errors.add('Failed to create slot $i: ${result.message}');
        }
      } catch (e) {
        errors.add('Error creating slot $i: $e');
      }
    }
    
    if (errors.isEmpty) {
      return OperationResult.success(
        data: createdAuctions,
        message: 'Successfully created ${createdAuctions.length} auction slots',
      );
    } else {
      return OperationResult(
        success: createdAuctions.isNotEmpty,
        data: createdAuctions,
        message: 'Created ${createdAuctions.length} slots with ${errors.length} errors: ${errors.join(', ')}',
      );
    }
  }
  
  /// Place a bid on a specific auction slot
  Future<OperationResult<double>> placeBidOnSlot({
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
  Future<OperationResult<bool>> finalizeSlot({
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
