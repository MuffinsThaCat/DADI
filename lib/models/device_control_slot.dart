class DeviceControlSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final String? owner;
  
  const DeviceControlSlot({
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.owner,
  });
  
  // Create a copy with modified properties
  DeviceControlSlot copyWith({
    DateTime? startTime,
    DateTime? endTime,
    bool? isAvailable,
    String? owner,
  }) {
    return DeviceControlSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAvailable: isAvailable ?? this.isAvailable,
      owner: owner ?? this.owner,
    );
  }
  
  // Check if this slot overlaps with another time range
  bool overlaps(DateTime start, DateTime end) {
    return (startTime.isBefore(end) && endTime.isAfter(start));
  }
  
  // Duration of the slot in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }
  
  // Format for display
  String get displayTimeRange {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }
  
  // Helper method to format time
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // Create from JSON data
  factory DeviceControlSlot.fromJson(Map<String, dynamic> json) {
    return DeviceControlSlot(
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isAvailable: json['isAvailable'] ?? true,
      owner: json['owner'],
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isAvailable': isAvailable,
      'owner': owner,
    };
  }
  
  @override
  String toString() {
    return 'DeviceControlSlot(startTime: $startTime, endTime: $endTime, isAvailable: $isAvailable, owner: $owner)';
  }
}
