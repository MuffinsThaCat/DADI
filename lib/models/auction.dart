import 'dart:developer' as developer;
import 'device_control_slot.dart';
import 'auction_status.dart';

class Auction {
  final String deviceId;
  final String owner;
  final DateTime startTime;
  final DateTime endTime;
  final double minimumBid;
  final double highestBid;
  final String highestBidder;
  final bool isActive;
  final bool isFinalized;
  final bool isUserCreated;
  final List<DeviceControlSlot> controlSlots;

  Auction({
    required this.deviceId,
    required this.owner,
    required this.startTime,
    required this.endTime,
    required this.minimumBid,
    this.highestBid = 0.0,
    this.highestBidder = '',
    required this.isActive,
    required this.isFinalized,
    required this.isUserCreated,
    List<DeviceControlSlot>? controlSlots,
  }) : controlSlots = controlSlots ?? [];

  /// Create an Auction from blockchain data
  factory Auction.fromBlockchainData(Map<String, dynamic> data) {
    try {
      // Extract the deviceId
      final String deviceId = data['deviceId'] as String? ?? 'unknown-device';
      
      // Handle various timestamp formats
      final startTime = data['startTime'] is DateTime
          ? data['startTime'] as DateTime
          : data['startTime'] is int
              ? DateTime.fromMillisecondsSinceEpoch(data['startTime'] as int)
              : DateTime.now().subtract(const Duration(hours: 1));
      
      // Check for endTime in different formats
      DateTime endTime;
      if (data['endTime'] is DateTime) {
        endTime = data['endTime'] as DateTime;
      } else if (data['endTimeBigInt'] is BigInt) {
        endTime = DateTime.fromMillisecondsSinceEpoch((data['endTimeBigInt'] as BigInt).toInt() * 1000);
      } else if (data['endTime'] is BigInt) {
        endTime = DateTime.fromMillisecondsSinceEpoch((data['endTime'] as BigInt).toInt() * 1000);
      } else if (data['endTime'] is int) {
        endTime = DateTime.fromMillisecondsSinceEpoch(data['endTime'] as int);
      } else {
        // Default to 1 hour after start if no valid end time
        endTime = startTime.add(const Duration(hours: 1));
      }
      
      // Extract other auction properties
      final String owner = data['owner'] as String? ?? '0x0000000000000000000000000000000000000000';
      
      // Handle minimum bid in different formats
      double minimumBid;
      if (data['minimumBid'] is double) {
        minimumBid = data['minimumBid'] as double;
      } else if (data['minBid'] is double) {
        minimumBid = data['minBid'] as double;
      } else if (data['minBid'] is BigInt) {
        minimumBid = (data['minBid'] as BigInt).toDouble() / 1e18;
      } else if (data['minimumBid'] is BigInt) {
        minimumBid = (data['minimumBid'] as BigInt).toDouble() / 1e18;
      } else {
        minimumBid = 0.1; // Default
      }
      
      // Handle highest bid
      double highestBid = 0.0;
      if (data['highestBid'] is double) {
        highestBid = data['highestBid'] as double;
      } else if (data['highestBid'] is BigInt) {
        highestBid = (data['highestBid'] as BigInt).toDouble() / 1e18;
      } else if (data['highestBid'] is String && (data['highestBid'] as String).isNotEmpty) {
        highestBid = double.tryParse(data['highestBid'] as String) ?? 0.0;
      }
      
      // Handle bidder
      final String highestBidder = data['highestBidder'] as String? ?? '0x0000000000000000000000000000000000000000';
      
      // Handle auction status
      final bool isActive = data['active'] as bool? ?? true;
      final bool isFinalized = data['finalized'] as bool? ?? false;
      
      // Explicitly check for user created flag
      final bool isUserCreated = data['isUserCreated'] as bool? ?? false;
      
      // Print debug info for this auction
      developer.log('Auction.fromBlockchainData: deviceId=$deviceId, isUserCreated=$isUserCreated, active=$isActive');
      
      return Auction(
        deviceId: deviceId,
        startTime: startTime,
        endTime: endTime,
        owner: owner,
        minimumBid: minimumBid,
        highestBid: highestBid,
        highestBidder: highestBidder,
        isActive: isActive,
        isFinalized: isFinalized,
        isUserCreated: isUserCreated, // Make sure we set the user created flag
        controlSlots: data['controlSlots'] != null ? data['controlSlots'].map((slot) => DeviceControlSlot.fromJson(slot)).toList() : [],
      );
    } catch (e) {
      // If anything goes wrong, throw a more descriptive error
      developer.log('Error creating Auction.fromBlockchainData: $e');
      developer.log('Data received: ${data.toString()}');
      rethrow;
    }
  }

  // Helper to convert bytes32 to string
  static String utf8ToHex(dynamic bytes32) {
    if (bytes32 is String) return bytes32;
    
    // Implementation would depend on the actual format of bytes32
    // This is a placeholder
    return bytes32.toString();
  }

  // Check if auction is currently open for bidding
  bool get isOpenForBidding {
    final now = DateTime.now();
    return isActive && 
           !isFinalized && 
           startTime.isBefore(now) && 
           endTime.isAfter(now);
  }

  // Check if auction has ended but not finalized
  bool get canBeFinalized {
    final now = DateTime.now();
    return isActive && 
           !isFinalized && 
           endTime.isBefore(now);
  }

  // Get time remaining in the auction
  Duration get timeRemaining {
    final now = DateTime.now();
    if (endTime.isBefore(now)) {
      return Duration.zero;
    }
    return endTime.difference(now);
  }

  // Get formatted time remaining string
  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    
    if (remaining == Duration.zero) {
      return 'Ended';
    }
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get auction status text
  String get statusText {
    if (isFinalized) {
      return 'Finalized';
    } else if (!isActive) {
      return 'Inactive';
    } else if (isOpenForBidding) {
      return 'Active';
    } else if (startTime.isAfter(DateTime.now())) {
      return 'Scheduled';
    } else {
      return 'Ended';
    }
  }

  // Get the current status of the auction
  AuctionStatus get status {
    if (!isActive) {
      return AuctionStatus.cancelled;
    }
    
    if (isFinalized) {
      return AuctionStatus.finalized;
    }
    
    final now = DateTime.now();
    if (endTime.isBefore(now)) {
      return AuctionStatus.ended;
    }
    
    return AuctionStatus.active;
  }

  // Copy with method for immutability
  Auction copyWith({
    String? deviceId,
    String? owner,
    DateTime? startTime,
    DateTime? endTime,
    double? minimumBid,
    double? highestBid,
    String? highestBidder,
    bool? isActive,
    bool? isFinalized,
    bool? isUserCreated,
    List<DeviceControlSlot>? controlSlots,
  }) {
    return Auction(
      deviceId: deviceId ?? this.deviceId,
      owner: owner ?? this.owner,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      minimumBid: minimumBid ?? this.minimumBid,
      highestBid: highestBid ?? this.highestBid,
      highestBidder: highestBidder ?? this.highestBidder,
      isActive: isActive ?? this.isActive,
      isFinalized: isFinalized ?? this.isFinalized,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      controlSlots: controlSlots ?? this.controlSlots,
    );
  }

  @override
  String toString() {
    return 'Auction{deviceId: $deviceId, owner: $owner, startTime: $startTime, endTime: $endTime, '
           'minimumBid: $minimumBid, highestBid: $highestBid, highestBidder: $highestBidder, '
           'isActive: $isActive, isFinalized: $isFinalized, isUserCreated: $isUserCreated, controlSlots: $controlSlots}';
  }
}
