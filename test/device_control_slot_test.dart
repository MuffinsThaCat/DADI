import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/device_control_slot.dart';

void main() {
  group('DeviceControlSlot', () {
    test('constructor creates instance with correct properties', () {
      final startTime = DateTime(2023, 1, 1, 10, 0);
      final endTime = DateTime(2023, 1, 1, 11, 0);
      
      final slot = DeviceControlSlot(
        startTime: startTime,
        endTime: endTime,
        isAvailable: true,
        owner: '0xTestOwner',
      );
      
      expect(slot.startTime, equals(startTime));
      expect(slot.endTime, equals(endTime));
      expect(slot.isAvailable, isTrue);
      expect(slot.owner, equals('0xTestOwner'));
    });
    
    test('copyWith creates a new instance with updated properties', () {
      final startTime = DateTime(2023, 1, 1, 10, 0);
      final endTime = DateTime(2023, 1, 1, 11, 0);
      final newStartTime = DateTime(2023, 1, 1, 12, 0);
      final newEndTime = DateTime(2023, 1, 1, 13, 0);
      
      final slot = DeviceControlSlot(
        startTime: startTime,
        endTime: endTime,
        isAvailable: true,
        owner: '0xTestOwner',
      );
      
      final updatedSlot = slot.copyWith(
        startTime: newStartTime,
        endTime: newEndTime,
        isAvailable: false,
        owner: '0xNewOwner',
      );
      
      // Original slot should remain unchanged
      expect(slot.startTime, equals(startTime));
      expect(slot.endTime, equals(endTime));
      expect(slot.isAvailable, isTrue);
      expect(slot.owner, equals('0xTestOwner'));
      
      // Updated slot should have new values
      expect(updatedSlot.startTime, equals(newStartTime));
      expect(updatedSlot.endTime, equals(newEndTime));
      expect(updatedSlot.isAvailable, isFalse);
      expect(updatedSlot.owner, equals('0xNewOwner'));
    });
    
    test('overlaps returns true when time ranges overlap', () {
      final slot = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 12, 0),
      );
      
      // Completely within
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 10, 30),
        DateTime(2023, 1, 1, 11, 30),
      ), isTrue);
      
      // Partially overlapping at start
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 9, 30),
        DateTime(2023, 1, 1, 10, 30),
      ), isTrue);
      
      // Partially overlapping at end
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 11, 30),
        DateTime(2023, 1, 1, 12, 30),
      ), isTrue);
      
      // Completely containing
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 9, 0),
        DateTime(2023, 1, 1, 13, 0),
      ), isTrue);
    });
    
    test('overlaps returns false when time ranges do not overlap', () {
      final slot = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 12, 0),
      );
      
      // Before
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 8, 0),
        DateTime(2023, 1, 1, 9, 0),
      ), isFalse);
      
      // After
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 13, 0),
        DateTime(2023, 1, 1, 14, 0),
      ), isFalse);
      
      // Edge case: ends exactly when slot starts
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 9, 0),
        DateTime(2023, 1, 1, 10, 0),
      ), isFalse);
      
      // Edge case: starts exactly when slot ends
      expect(slot.overlaps(
        DateTime(2023, 1, 1, 12, 0),
        DateTime(2023, 1, 1, 13, 0),
      ), isFalse);
    });
    
    test('durationMinutes returns correct duration', () {
      // 1 hour slot
      final slot1 = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 11, 0),
      );
      expect(slot1.durationMinutes, equals(60));
      
      // 30 minute slot
      final slot2 = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 10, 30),
      );
      expect(slot2.durationMinutes, equals(30));
      
      // 1 day slot
      final slot3 = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 2, 10, 0),
      );
      expect(slot3.durationMinutes, equals(24 * 60));
    });
    
    test('displayTimeRange formats time correctly', () {
      final slot = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 9, 5),
        endTime: DateTime(2023, 1, 1, 17, 30),
      );
      
      expect(slot.displayTimeRange, equals('09:05 - 17:30'));
    });
    
    test('toString returns a descriptive string', () {
      final slot = DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 11, 0),
        isAvailable: true,
        owner: '0xTestOwner',
      );
      
      expect(slot.toString(), contains('startTime'));
      expect(slot.toString(), contains('endTime'));
      expect(slot.toString(), contains('isAvailable: true'));
      expect(slot.toString(), contains('owner: 0xTestOwner'));
    });
  });
}
