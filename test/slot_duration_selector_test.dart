import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/widgets/slot_duration_selector.dart';

void main() {
  testWidgets('SlotDurationSelector displays available durations and handles selection', (WidgetTester tester) async {
    int selectedDuration = 2;
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotDurationSelector(
            selectedDuration: selectedDuration,
            onDurationSelected: (duration) {
              selectedDuration = duration;
            },
          ),
        ),
      ),
    );
    
    // Verify the widget displays the title
    expect(find.text('Select Time Slot Duration'), findsOneWidget);
    
    // Verify all duration options are displayed
    expect(find.text('2 min'), findsOneWidget);
    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('4 min'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    
    // Tap on the 4-minute option
    await tester.tap(find.text('4 min'));
    await tester.pump();
    
    // Verify the selection was updated
    expect(selectedDuration, 4);
    
    // Tap on the 5-minute option
    await tester.tap(find.text('5 min'));
    await tester.pump();
    
    // Verify the selection was updated again
    expect(selectedDuration, 5);
  });
  
  testWidgets('SlotDurationSelector can use custom durations', (WidgetTester tester) async {
    int selectedDuration = 10;
    
    // Build the widget with custom durations
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotDurationSelector(
            selectedDuration: selectedDuration,
            onDurationSelected: (duration) {
              selectedDuration = duration;
            },
            availableDurations: [5, 10, 15, 20],
          ),
        ),
      ),
    );
    
    // Verify custom duration options are displayed
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    
    // Default durations should not be present
    expect(find.text('2 min'), findsNothing);
    expect(find.text('3 min'), findsNothing);
    
    // Tap on the 15-minute option
    await tester.tap(find.text('15 min'));
    await tester.pump();
    
    // Verify the selection was updated
    expect(selectedDuration, 15);
  });
}
