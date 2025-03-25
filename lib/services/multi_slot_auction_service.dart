import 'dart:developer' as developer;
import 'dart:math' as math;
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
    // Format the session ID to match what's expected in _extractBaseDeviceId
    final sessionId = '$sessionName-session-${DateTime.now().millisecondsSinceEpoch}';
    
    _log('Creating multi-slot auction:');
    _log('  Session ID: $sessionId');
    _log('  Session Name: $sessionName');
    _log('  Start Time: $startTime');
    _log('  Slot Duration: $slotDurationMinutes minutes');
    _log('  Slot Count: $slotCount');
    _log('  Minimum Bid: $minimumBid ETH');
    
    try {
      // Enforce 5-minute slots regardless of input parameter
      final int fixedSlotDurationMinutes = 5;
      
      // Calculate total number of 5-minute slots based on the requested duration
      final int totalSlots = (slotDurationMinutes * slotCount) ~/ fixedSlotDurationMinutes;
      
      _log('  Using fixed 5-minute slots');
      _log('  Total 5-minute slots: $totalSlots');
      
      // Calculate slot durations with fixed and consistent spacing
      final List<DateTime> slotStartTimes = [];
      final List<DateTime> slotEndTimes = [];
      
      // Create all the slots
      for (int i = 0; i < totalSlots; i++) {
        // Each slot is exactly 5 minutes with no overlap
        final slotStartTime = startTime.add(Duration(minutes: i * fixedSlotDurationMinutes));
        final slotEndTime = slotStartTime.add(Duration(minutes: fixedSlotDurationMinutes));
        
        slotStartTimes.add(slotStartTime);
        slotEndTimes.add(slotEndTime);
        
        // Create unique slot ID that includes the session ID and slot number
        final slotId = '$sessionId-slot-$i';
        
        // Generate a random buffer between 1-5 minutes
        final random = math.Random();
        final biddingEndBuffer = random.nextInt(5) + 1; // 1-5 minutes
        
        // Calculate bidding end time (1-5 minutes before slot starts)
        final biddingEndTime = slotStartTime.subtract(Duration(minutes: biddingEndBuffer));
        
        _log('Creating slot $i:');
        _log('  Slot ID: $slotId');
        _log('  Slot Start Time: $slotStartTime');
        _log('  Slot End Time: $slotEndTime');
        _log('  Slot Duration: $fixedSlotDurationMinutes minutes');
        _log('  Bidding End Buffer: $biddingEndBuffer minutes (random 1-5 minutes)');
        _log('  Bidding End Time: $biddingEndTime');
        
        // Store actual slot duration in additionalData, but bidding ends early
        // The blockchain auction runs from biddingEndTime to slotStartTime (when bidding is active)
        final result = await _web3Service.createAuction(
          deviceId: slotId,
          startTime: biddingEndTime, // Bidding starts whenever the auction is created
          duration: _calculateMinutesBetween(biddingEndTime, slotStartTime), // Duration until slot starts
          minimumBid: minimumBid,
          isUserCreated: true,
          biddingEndBufferMinutes: biddingEndBuffer, // Pass the random buffer to the contract
          // Add session metadata for proper grouping in the creator dashboard
          additionalData: {
            'sessionId': sessionId,
            'sessionName': sessionName,
            'slotNumber': i,
            'slotCount': totalSlots,
            'isSession': false,
            'actualSlotStartTime': slotStartTime.toIso8601String(),
            'actualSlotEndTime': slotEndTime.toIso8601String(),
            'biddingEndBuffer': biddingEndBuffer,
          },
        );
        
        if (!result.success) {
          _log('Failed to create slot: ${result.message}');
          return OperationResult(
            success: false,
            message: 'Failed to create slot $i: ${result.message}',
          );
        }
      }
      
      _log('✅ All $totalSlots slots created successfully');
      
      // Debug: Get the IDs of all active auctions before refresh
      _log('Active auctions before refresh: ${_web3Service.activeAuctions.keys.join(', ')}');
      
      // Force refresh auctions after creating all slots
      await _web3Service.loadActiveAuctions(forceRefresh: true);

      // Debug: Get the IDs of all active auctions after refresh
      _log('Active auctions after refresh: ${_web3Service.activeAuctions.keys.join(', ')}');
      
      return OperationResult(
        success: true,
        message: 'Successfully created $totalSlots auction slots',
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
    _log('Attempting to place bid of $amount ETH on slot starting at ${slotStartTime.toIso8601String()}');
    _log('For device: $deviceId');
    
    // Check first if we're using mock mode, as this will change how we handle the bidding
    final bool isMockMode = _web3Service.isMockMode;
    _log('Mock mode check: $isMockMode');
    
    // Try to find the auction ID based on device ID and slot start time
    final allAuctionIds = _web3Service.activeAuctions.keys.toList();
    
    // Construct possible auction IDs for this slot
    String actualAuctionId = '';
    
    // For slot auctions, the ID typically includes the session ID and slot number
    // First, try to find an ID with the device ID and a matching slot pattern
    for (final id in allAuctionIds) {
      if (id.startsWith(deviceId) || id.contains('session')) {
        _log('Found potential matching ID: $id');
        
        // Check if this auction has a matching start time
        final auctionData = _web3Service.activeAuctions[id];
        if (auctionData != null) {
          final startTimeStr = auctionData['startTime'] as String?;
          if (startTimeStr != null) {
            try {
              final auctionStartTime = DateTime.parse(startTimeStr);
              // Compare with a small tolerance for time differences
              final difference = auctionStartTime.difference(slotStartTime).inSeconds.abs();
              if (difference < 60) { // Within 1 minute
                _log('Found matching auction with ID: $id (time difference: ${difference}s)');
                actualAuctionId = id;
                break;
              }
            } catch (e) {
              _log('Error parsing date: $e');
            }
          }
        }
      }
    }
    
    // If we still don't have an ID, try broader matching approaches
    if (actualAuctionId.isEmpty) {
      _log('No direct match found, trying broader approaches');
      
      // Look for other IDs that might match this slot
      // First try the format with -slot- in it
      final legacyFormatId = '$deviceId-slot-${slotStartTime.millisecondsSinceEpoch}';
      if (_web3Service.activeAuctions.containsKey(legacyFormatId)) {
        _log('Found matching auction with legacy format ID: $legacyFormatId');
        actualAuctionId = legacyFormatId;
      } else {
        // Try to find any ID that could be related to this device and slot
        final potentialIds = allAuctionIds.where((id) => 
          id.contains(deviceId) && 
          (id.contains(slotStartTime.millisecondsSinceEpoch.toString()) || 
           id.contains('-slot-'))
        ).toList();
        
        if (potentialIds.isNotEmpty) {
          _log('Found potential matching IDs: $potentialIds');
          actualAuctionId = potentialIds.first;
        }
      }
    }
    
    // If still no match, search for any auction ID containing the device ID
    if (actualAuctionId.isEmpty) {
      final deviceRelatedIds = allAuctionIds.where((id) => id.contains(deviceId)).toList();
      if (deviceRelatedIds.isNotEmpty) {
        _log('Fallback: Using device-related ID: ${deviceRelatedIds.first}');
        actualAuctionId = deviceRelatedIds.first;
      }
    }
    
    _log('Using auction ID for bid: $actualAuctionId');
    
    // Check if we're in mock mode and use the appropriate bid method
    if (_web3Service.isMockMode) {
      _log('Using mock bid in mock mode to avoid metatransaction relayer');
      
      // For mock mode, we'll update the auction directly to ensure consistency
      if (_web3Service.activeAuctions.containsKey(actualAuctionId)) {
        // Extract the current auction data
        final currentData = _web3Service.activeAuctions[actualAuctionId]!;
        
        // Ensure we update both highestBid and minimumBid
        _log('Current auction data before update: $currentData');
        
        // Create updated data with a new object to ensure reference changes
        final updatedData = Map<String, dynamic>.from(currentData);
        updatedData['highestBid'] = amount;
        updatedData['minimumBid'] = amount; // This is critical - ensure minimumBid is updated
        updatedData['highestBidder'] = _web3Service.currentAddress ?? "0xMockBidder";
        
        // Update the auction in memory with a completely new object
        _web3Service.activeAuctions[actualAuctionId] = updatedData;
        
        _log('Updated auction data directly: $updatedData');
        
        // Force updates via the proper method instead of calling notifyListeners directly
        _web3Service.loadActiveAuctions(forceRefresh: true);
      }
      
      // CRITICAL CHANGE: Force refresh the auction data in both services
      _web3Service.loadActiveAuctions(forceRefresh: true);
      
      // In mock mode, use the mock bid functionality directly with forceWin
      final result = await _web3Service.placeMockBid(
        actualAuctionId, 
        amount, 
        forceWin: true
      );
      
      _log('Mock bid result: ${result.success}, message: ${result.message}');
      if (result.data != null) {
        _log('Updated auction data from result: ${result.data}');
      }
      
      // Manually verify the data after the bid
      if (_web3Service.activeAuctions.containsKey(actualAuctionId)) {
        final afterBidData = _web3Service.activeAuctions[actualAuctionId]!;
        _log('Verification - Auction data after bid: $afterBidData');
        _log('Verification - highestBid: ${afterBidData['highestBid']}, minimumBid: ${afterBidData['minimumBid']}');
        
        // Force another refresh to ensure listeners update
        _web3Service.loadActiveAuctions(forceRefresh: true);
        
        // Create an enhanced result with explicit data fields to ensure UI updates correctly
        return OperationResult(
          success: true,
          message: 'Bid placed successfully',
          data: {
            'highestBid': amount,  // Use the exact amount we used to ensure consistency
            'minimumBid': amount,  // Use the exact amount we used to ensure consistency
            'highestBidder': _web3Service.currentAddress ?? "0xMockBidder",
            'deviceId': actualAuctionId,
            'auctionData': afterBidData
          },
        );
      }
      
      // If we get here, something went wrong with the data update
      _log('ERROR: Could not verify auction data after bid');
      return OperationResult(
        success: false,
        message: 'Error updating auction data after bid',
      );
    }
    
    // For real mode, generate UI signature and use placeBidNew
    final uiSignature = _web3Service.generateUISignature(actualAuctionId);
    
    final result = await _web3Service.placeBidNew(
      deviceId: actualAuctionId,
      amount: amount,
      uiSignature: uiSignature, // Add UI signature
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
  
  /// Calculate minutes between two DateTime objects
  int _calculateMinutesBetween(DateTime start, DateTime end) {
    return end.difference(start).inMinutes;
  }
  
  void _log(String message) {
    developer.log(message, name: 'MultiSlotAuctionService');
  }
}
