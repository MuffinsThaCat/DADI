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
    List<DeviceControlSlot>? controlSlots,
  }) : controlSlots = controlSlots ?? [];

  // Create from blockchain data
  factory Auction.fromBlockchainData(Map<String, dynamic> data) {
    final startTimeUnix = data['startTime'] is BigInt 
        ? (data['startTime'] as BigInt).toInt() 
        : data['startTime'] is DateTime
            ? (data['startTime'] as DateTime).millisecondsSinceEpoch ~/ 1000
            : (data['startTime'] as int);
    
    final endTimeUnix = data['endTime'] is BigInt 
        ? (data['endTime'] as BigInt).toInt() 
        : data['endTime'] is DateTime
            ? (data['endTime'] as DateTime).millisecondsSinceEpoch ~/ 1000
            : (data['endTime'] as int);
    
    final highestBidWei = data['highestBid'] is BigInt 
        ? (data['highestBid'] as BigInt) 
        : BigInt.from(data['highestBid'] as int);
    
    // Convert wei to ETH (1 ETH = 10^18 wei)
    final highestBidEth = highestBidWei.toDouble() / 1e18;
    
    return Auction(
      deviceId: data['deviceId'] is String ? data['deviceId'] : utf8ToHex(data['deviceId']),
      owner: data['owner'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(startTimeUnix * 1000),
      endTime: DateTime.fromMillisecondsSinceEpoch(endTimeUnix * 1000),
      minimumBid: data['minimumBid'] is double 
          ? data['minimumBid'] 
          : 0.01, // Default minimum bid if not provided
      highestBid: highestBidEth,
      highestBidder: data['highestBidder'] as String,
      isActive: data['active'] == null ? true : data['active'] as bool,
      isFinalized: data['finalized'] == null ? false : data['finalized'] as bool,
      controlSlots: data['controlSlots'] != null ? data['controlSlots'].map((slot) => DeviceControlSlot.fromJson(slot)).toList() : [],
    );
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
      controlSlots: controlSlots ?? this.controlSlots,
    );
  }

  @override
  String toString() {
    return 'Auction{deviceId: $deviceId, owner: $owner, startTime: $startTime, endTime: $endTime, '
           'minimumBid: $minimumBid, highestBid: $highestBid, highestBidder: $highestBidder, '
           'isActive: $isActive, isFinalized: $isFinalized, controlSlots: $controlSlots}';
  }
}
