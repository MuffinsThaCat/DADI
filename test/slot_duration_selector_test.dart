import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/widgets/slot_duration_selector.dart';

void main() {
  testWidgets('SlotDurationSelector displays available durations and handles selection', (WidgetTester tester) async {
    int selectedDuration = 15;
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotDurationSelector(
            selectedDuration: selectedDuration,
            onDurationSelected: (duration) {
              selectedDuration = duration;
            },
            // Use custom durations that match what we expect to test
            availableDurations: [15, 30, 45, 60, 90, 120, 240],
          ),
        ),
      ),
    );
    
    // Verify the widget displays the title
    expect(find.text('Select Time Slot Duration'), findsOneWidget);
    
    // Verify duration options are displayed
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('120 min'), findsOneWidget);
    expect(find.text('240 min'), findsOneWidget);
    
    // Tap on the 45-minute option
    await tester.tap(find.text('45 min'));
    await tester.pump();
    
    // Verify the selection was updated
    expect(selectedDuration, 45);
    
    // Tap on the 60-minute option
    await tester.tap(find.text('60 min'));
    await tester.pump();
    
    // Verify the selection was updated again
    expect(selectedDuration, 60);
  });
  
  testWidgets('SlotDurationSelector can use custom durations', (WidgetTester tester) async {
    int selectedDuration = 15;
    
    // Build the widget with custom durations
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotDurationSelector(
            selectedDuration: selectedDuration,
            onDurationSelected: (duration) {
              selectedDuration = duration;
            },
            availableDurations: [15, 30, 45, 60],
          ),
        ),
      ),
    );
    
    // Verify custom duration options are displayed
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
    
    // Default durations should not be present if not in custom list
    expect(find.text('90 min'), findsNothing);
    expect(find.text('120 min'), findsNothing);
    expect(find.text('240 min'), findsNothing);
    
    // Tap on the 45-minute option
    await tester.tap(find.text('45 min'));
    await tester.pump();
    
    // Verify the selection was updated
    expect(selectedDuration, 45);
  });
}
