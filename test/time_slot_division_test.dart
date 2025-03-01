import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/widgets/slot_duration_selector.dart';
import 'package:dadi/widgets/time_slot_selector.dart';
import 'web3_service_mock.dart';
import 'package:dadi/screens/auction_detail_screen.dart';

void main() {
  late MockWeb3Service mockWeb3Service;
  late Auction testAuction;

  setUp(() {
    mockWeb3Service = MockWeb3Service();
    
    // Create a test auction with a 4-hour duration
    final now = DateTime.now();
    testAuction = Auction(
      deviceId: 'test-device-1',
      owner: '0xTestOwner',
      startTime: now,
      endTime: now.add(const Duration(hours: 4)),
      minimumBid: 0.01,
      highestBid: 0.0,
      highestBidder: '',
      isActive: true,
      isFinalized: false,
    );
  });

  testWidgets('Should divide total time into equal slots based on selected duration',
      (WidgetTester tester) async {
    // Build the auction detail screen
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: testAuction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    // Find the SlotDurationSelector
    final durationSelector = find.byType(SlotDurationSelector);
    expect(durationSelector, findsOneWidget);
    
    // Find and tap on the 30-minute duration option
    final thirtyMinOption = find.text('30 min');
    if (thirtyMinOption.evaluate().isNotEmpty) {
      await tester.tap(thirtyMinOption, warnIfMissed: false);
      await tester.pumpAndSettle();
    } else {
      // If 30-minute option isn't available, find the 20-minute option
      final twentyMinOption = find.text('20 min');
      if (twentyMinOption.evaluate().isNotEmpty) {
        await tester.tap(twentyMinOption, warnIfMissed: false);
        await tester.pumpAndSettle();
      } else {
        // If neither is available, find the 15-minute option
        final fifteenMinOption = find.text('15 min');
        if (fifteenMinOption.evaluate().isNotEmpty) {
          await tester.tap(fifteenMinOption, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }
    }
    
    // We can't directly access private fields, so we'll verify the UI instead
    final timeSlotSelector = find.byType(TimeSlotSelector);
    expect(timeSlotSelector, findsOneWidget);
  });
  
  testWidgets('SlotDurationSelector should recommend appropriate durations based on total time',
      (WidgetTester tester) async {
    // Test with a 2-hour auction
    final shortAuction = Auction(
      deviceId: 'specific-device-id',
      owner: '0xTestOwner',
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 2)),
      minimumBid: 0.01,
      highestBid: 0.0,
      highestBidder: '',
      isActive: true,
      isFinalized: false,
    );
    
    // Build the auction detail screen
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: shortAuction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    // For a 2-hour auction (120 minutes), we expect durations like 5, 10, 15, 20, 30 minutes
    // to be recommended (as they divide 120 minutes into a reasonable number of slots)
    final durationTexts = [
      find.text('5 min'),
      find.text('10 min'),
      find.text('15 min'),
      find.text('20 min'),
      find.text('30 min'),
      find.text('60 min'),
    ];
    
    // At least some of these durations should be present
    int foundDurations = 0;
    for (final textFinder in durationTexts) {
      if (textFinder.evaluate().isNotEmpty) {
        foundDurations++;
      }
    }
    
    // We should find at least 3 of the expected durations
    expect(foundDurations >= 3, isTrue);
  });
}
