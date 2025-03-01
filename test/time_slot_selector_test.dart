import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/device_control_slot.dart';
import 'package:dadi/widgets/time_slot_selector.dart';

void main() {
  group('TimeSlotSelector', () {
    final testSlots = [
      DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 10, 0),
        endTime: DateTime(2023, 1, 1, 11, 0),
        isAvailable: true,
      ),
      DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 11, 0),
        endTime: DateTime(2023, 1, 1, 12, 0),
        isAvailable: true,
      ),
      DeviceControlSlot(
        startTime: DateTime(2023, 1, 1, 12, 0),
        endTime: DateTime(2023, 1, 1, 13, 0),
        isAvailable: false,
        owner: '0xSomeOwner',
      ),
    ];
    
    testWidgets('renders correctly with slots', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: null,
            ),
          ),
        ),
      );
      
      // Check if the title is displayed
      expect(find.text('Select Time Slot'), findsOneWidget);
      
      // Check if all slots are displayed
      expect(find.text('10:00 - 11:00'), findsOneWidget);
      expect(find.text('11:00 - 12:00'), findsOneWidget);
      expect(find.text('12:00 - 13:00'), findsOneWidget);
      
      // Check if durations are displayed
      expect(find.text('60 min'), findsNWidgets(3));
      
      // Check if unavailable slot is marked
      expect(find.text('Unavailable'), findsOneWidget);
    });
    
    testWidgets('renders message when no slots are available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: [],
              onSlotSelected: null,
            ),
          ),
        ),
      );
      
      // Check if the no slots message is displayed
      expect(find.text('No available time slots for this auction'), findsOneWidget);
    });
    
    testWidgets('selects a slot when tapped', (WidgetTester tester) async {
      DeviceControlSlot? selectedSlot;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: (slot) {
                selectedSlot = slot;
              },
            ),
          ),
        ),
      );
      
      // Initial value should be null
      expect(selectedSlot, isNull);
      
      // Tap on the first available slot
      await tester.tap(find.text('10:00 - 11:00'));
      await tester.pump();
      
      // Check if the callback was called with the correct slot
      expect(selectedSlot, equals(testSlots[0]));
      
      // Tap on the second available slot
      await tester.tap(find.text('11:00 - 12:00'));
      await tester.pump();
      
      // Check if the callback was called with the correct slot
      expect(selectedSlot, equals(testSlots[1]));
    });
    
    testWidgets('cannot select unavailable slots', (WidgetTester tester) async {
      DeviceControlSlot? selectedSlot;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: null,
            ),
          ),
        ),
      );
      
      // Initial value should be null
      expect(selectedSlot, isNull);
      
      // Tap on the unavailable slot
      await tester.tap(find.text('12:00 - 13:00'));
      await tester.pump();
      
      // Check that the callback was not called (selectedSlot remains null)
      expect(selectedSlot, isNull);
    });
    
    testWidgets('shows initially selected slot', (WidgetTester tester) async {
      final initiallySelectedSlot = testSlots[1];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: (slot) {},
              selectedSlot: initiallySelectedSlot,
            ),
          ),
        ),
      );
      
      // Check that the second slot has the selected styling
      // This is a bit tricky to test directly, so we'll check for the container with the selected slot
      final selectedSlotFinder = find.ancestor(
        of: find.text('11:00 - 12:00'),
        matching: find.byType(Container),
      ).first;
      
      final Container container = tester.widget<Container>(selectedSlotFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      
      // Selected slots should have a border width of 2
      expect((decoration.border as Border).top.width, equals(2));
    });
    
    testWidgets('updates selected slot when widget is updated', (WidgetTester tester) async {
      // Start with no selected slot
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: (slot) {},
            ),
          ),
        ),
      );
      
      // Update the widget with a selected slot
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSlotSelector(
              slots: testSlots,
              onSlotSelected: (slot) {},
              selectedSlot: testSlots[0],
            ),
          ),
        ),
      );
      
      // Check that the first slot has the selected styling
      final selectedSlotFinder = find.ancestor(
        of: find.text('10:00 - 11:00'),
        matching: find.byType(Container),
      ).first;
      
      final Container container = tester.widget<Container>(selectedSlotFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      
      // Selected slots should have a border width of 2
      expect((decoration.border as Border).top.width, equals(2));
    });
  });
}
