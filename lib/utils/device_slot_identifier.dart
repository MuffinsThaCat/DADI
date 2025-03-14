/// Utility class for handling device slot identifiers
class DeviceSlotIdentifier {
  /// Generate a composite device ID for a specific time slot
  /// Combines the physical device ID with the slot start time in a recoverable format
  static String generateSlotDeviceId(String deviceId, DateTime slotStartTime) {
    // Create a predictable format that can be parsed later
    // Use a format like "deviceID::timestamp" where timestamp is unix milliseconds
    final timestamp = slotStartTime.millisecondsSinceEpoch;
    return '$deviceId::$timestamp';
  }
  
  /// Extract the original device ID and start time from a composite ID
  static Map<String, dynamic> parseCompositeId(String compositeId) {
    // Check if this is a composite ID (contains the separator)
    if (compositeId.contains('::')) {
      final parts = compositeId.split('::');
      if (parts.length >= 2) {
        try {
          final timestamp = int.parse(parts[1]);
          return {
            'deviceId': parts[0],
            'slotStartTime': DateTime.fromMillisecondsSinceEpoch(timestamp),
            'isSlot': true
          };
        } catch (e) {
          // Failed to parse timestamp, return defaults
        }
      }
    }
    
    // Not a composite ID or couldn't parse properly
    return {
      'deviceId': compositeId,
      'slotStartTime': null,
      'isSlot': false
    };
  }
  
  /// Check if a device ID is a composite slot ID
  static bool isCompositeId(String deviceId) {
    return deviceId.contains('::');
  }
}
