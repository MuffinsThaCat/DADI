import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dadi/models/auction.dart';
import 'package:dadi/models/device_control_slot.dart';
import 'package:dadi/models/operation_result.dart';
import 'package:dadi/screens/auction_detail_screen.dart';
import 'package:dadi/services/web3_service.dart';
import 'package:dadi/widgets/time_slot_selector.dart';
import 'package:dadi/widgets/slot_duration_selector.dart';

@GenerateMocks([Web3Service])
import 'auction_detail_screen_test.mocks.dart';

void main() {
  late MockWeb3Service mockWeb3Service;
  
  setUp(() {
    mockWeb3Service = MockWeb3Service();
    
    // Set up default behavior for the mock
    when(mockWeb3Service.currentAddress).thenReturn('0xMockAddress');
  });
  
  testWidgets('AuctionDetailScreen renders auction details', (WidgetTester tester) async {
    // Set screen size to a reasonable phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });
    
    // Create a test auction
    final auction = Auction(
      deviceId: 'test-device-id',
      owner: '0xMockOwner',
      startTime: DateTime(2023, 1, 1, 10, 0),
      endTime: DateTime(2023, 1, 1, 14, 0),
      minimumBid: 0.1,
      highestBid: 0.2,
      highestBidder: '0xMockBidder',
      isActive: true,
      isFinalized: false,
    );
    
    // Mock the getAuction method to return the same auction
    when(mockWeb3Service.getAuction(deviceId: anyNamed('deviceId'))).thenAnswer((_) async {
      return OperationResult(
        success: true,
        data: auction,
      );
    });
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: auction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    // Wait for the initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for the refresh to complete
    await tester.pumpAndSettle();
    
    // Verify that auction details are displayed
    expect(find.text('Device ID: test-device-id'), findsOneWidget);
    expect(find.text('Owner: 0xMockOwner'), findsOneWidget);
    expect(find.text('Minimum Bid: 0.1 ETH'), findsOneWidget);
    expect(find.text('Highest Bid: 0.2 ETH'), findsOneWidget);
    expect(find.text('Highest Bidder: 0xMockBidder'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Not Finalized'), findsOneWidget);
  });
  
  testWidgets('AuctionDetailScreen allows bidding on auction', (WidgetTester tester) async {
    // Set screen size to a reasonable phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });
    
    // Create a test auction where the current user is not the owner
    final auction = Auction(
      deviceId: 'test-device-id',
      owner: '0xOtherOwner', // Different from current address
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now().add(const Duration(hours: 1)),
      minimumBid: 0.1,
      highestBid: 0.2,
      highestBidder: '0xMockBidder',
      isActive: true,
      isFinalized: false,
    );
    
    // Mock the getAuction method to return the same auction
    when(mockWeb3Service.getAuction(deviceId: anyNamed('deviceId'))).thenAnswer((_) async {
      return OperationResult(
        success: true,
        data: auction,
      );
    });
    
    // Mock the placeBidNew method
    when(mockWeb3Service.placeBidNew(
      deviceId: anyNamed('deviceId'),
      amount: anyNamed('amount'),
    )).thenAnswer((_) async {
      return OperationResult(
        success: true,
        message: 'Bid placed successfully',
      );
    });
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: auction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    // Wait for the refresh to complete
    await tester.pumpAndSettle();
    
    // Verify that the bid form is displayed
    expect(find.text('Place a Bid'), findsOneWidget);
    expect(find.text('Bid Amount (ETH)'), findsOneWidget);
    expect(find.text('Place Bid'), findsOneWidget);
    
    // First, select a time slot (required for bidding)
    final timeSlotSelector = find.byType(TimeSlotSelector);
    expect(timeSlotSelector, findsOneWidget);
    
    // Find the first time slot and tap it
    final timeSlot = find.byType(GestureDetector).first;
    await tester.tap(timeSlot, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Enter a bid amount
    await tester.enterText(find.byType(TextField), '0.3');
    
    // Tap the bid button with warnIfMissed: false to avoid warnings in case the button is partially off-screen
    await tester.tap(find.text('Place Bid'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Verify that placeBidNew was called
    verify(mockWeb3Service.placeBidNew(
      deviceId: auction.deviceId,
      amount: 0.3,
    )).called(1);
  });
  
  testWidgets('AuctionDetailScreen allows finalizing auction', (WidgetTester tester) async {
    // Set screen size to a reasonable phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });
    
    // Create an ended auction where the current user is the owner
    final endedAuction = Auction(
      deviceId: 'test-device-id',
      owner: '0xMockAddress', // Same as currentAddress in mockWeb3Service
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      endTime: DateTime.now().subtract(const Duration(hours: 1)), // Auction has ended
      minimumBid: 0.1,
      highestBid: 0.2,
      highestBidder: '0xMockBidder',
      isActive: true, // Still active but ended
      isFinalized: false,
    );
    
    // Track if the auction has been finalized in our mock
    bool auctionFinalized = false;
    
    // Mock the getAuction method to return the appropriate auction state
    when(mockWeb3Service.getAuction(deviceId: anyNamed('deviceId'))).thenAnswer((_) async {
      if (auctionFinalized) {
        return OperationResult(
          success: true,
          data: endedAuction.copyWith(isFinalized: true, isActive: false),
        );
      } else {
        return OperationResult(
          success: true,
          data: endedAuction,
        );
      }
    });
    
    // Mock the finalizeAuctionNew method
    when(mockWeb3Service.finalizeAuctionNew(
      deviceId: anyNamed('deviceId'),
    )).thenAnswer((_) async {
      auctionFinalized = true;
      return OperationResult(
        success: true,
        data: true,
        message: 'Auction finalized successfully',
      );
    });
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: endedAuction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    // Wait for the refresh to complete
    await tester.pumpAndSettle();
    
    // Verify that the finalize button is displayed
    expect(find.text('Finalize Auction'), findsOneWidget);
    
    // Tap the finalize button with warnIfMissed: false
    await tester.tap(find.text('Finalize Auction'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Verify that finalizeAuctionNew was called
    verify(mockWeb3Service.finalizeAuctionNew(
      deviceId: endedAuction.deviceId,
    )).called(1);
  });
  
  testWidgets('AuctionDetailScreen allows cancelling auction', (WidgetTester tester) async {
    // Set screen size to a reasonable phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });
    
    // Create an auction with no bids where the current user is the owner
    final noBidsAuction = Auction(
      deviceId: 'test-device-id',
      owner: '0xMockAddress', // Same as currentAddress in mockWeb3Service
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now().add(const Duration(hours: 1)),
      minimumBid: 0.1,
      highestBid: 0, // No bids
      highestBidder: '0x0000000000000000000000000000000000000000', // Empty bidder address
      isActive: true,
      isFinalized: false,
    );
    
    // Track if the auction has been cancelled in our mock
    bool auctionCancelled = false;
    
    // Mock the getAuction method to return the appropriate auction state
    when(mockWeb3Service.getAuction(deviceId: anyNamed('deviceId'))).thenAnswer((_) async {
      if (auctionCancelled) {
        return OperationResult(
          success: true,
          data: noBidsAuction.copyWith(isActive: false),
        );
      } else {
        return OperationResult(
          success: true,
          data: noBidsAuction,
        );
      }
    });
    
    // Mock the cancelAuction method
    when(mockWeb3Service.cancelAuction(
      deviceId: anyNamed('deviceId'),
    )).thenAnswer((_) async {
      auctionCancelled = true;
      return OperationResult(
        success: true,
        message: 'Auction cancelled successfully',
      );
    });
    
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: noBidsAuction,
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    // Wait for the refresh to complete
    await tester.pumpAndSettle();
    
    // Verify that the cancel button is displayed
    expect(find.text('Cancel Auction'), findsOneWidget);
    
    // Tap the cancel button with warnIfMissed: false
    await tester.tap(find.text('Cancel Auction'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Confirm the cancellation with warnIfMissed: false
    await tester.tap(find.text('Yes'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Verify that cancelAuction was called
    verify(mockWeb3Service.cancelAuction(
      deviceId: noBidsAuction.deviceId,
    )).called(1);
  });
  
  testWidgets('AuctionDetailScreen allows changing time slot duration', (WidgetTester tester) async {
    // Set screen size to a reasonable phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });
    
    // Set up mock Web3Service
    final mockWeb3Service = MockWeb3Service();
    
    // Mock current user address (not the owner)
    when(mockWeb3Service.currentAddress).thenReturn('0x1234567890123456789012345678901234567890');
    
    // Mock getAuction method
    when(mockWeb3Service.getAuction(deviceId: anyNamed('deviceId'))).thenAnswer((_) async {
      return OperationResult(
        success: true,
        data: Auction(
          deviceId: '123',
          owner: '0x0987654321098765432109876543210987654321',
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          minimumBid: 0.1,
          highestBid: 0.2,
          highestBidder: '0x5678901234567890123456789012345678901234',
          isActive: true,
          isFinalized: false,
        ),
      );
    });
    
    // Build the AuctionDetailScreen widget
    await tester.pumpWidget(
      MaterialApp(
        home: AuctionDetailScreen(
          auction: Auction(
            deviceId: '123',
            owner: '0x0987654321098765432109876543210987654321',
            startTime: DateTime.now().subtract(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            minimumBid: 0.1,
            highestBid: 0.2,
            highestBidder: '0x5678901234567890123456789012345678901234',
            isActive: true,
            isFinalized: false,
          ),
          web3Service: mockWeb3Service,
        ),
      ),
    );
    
    // Wait for the widget to build
    await tester.pumpAndSettle();
    
    // Verify the default duration selector is present
    expect(find.byType(SlotDurationSelector), findsOneWidget);
    
    // Find the selected duration text (which should be bold)
    final selectedDurationFinder = find.text('2 min').evaluate().where((element) {
      final widget = element.widget as Text;
      return widget.style?.fontWeight == FontWeight.bold;
    });
    expect(selectedDurationFinder.length, 1);
    
    // Tap on the 4-minute option
    await tester.tap(find.text('4 min'));
    await tester.pumpAndSettle();
    
    // Verify that time slots are regenerated with the new duration
    // This is hard to verify directly, but we can check that the 4-minute option is now selected
    final Finder durationSelector = find.byType(SlotDurationSelector);
    expect(durationSelector, findsOneWidget);
    
    // Verify that the TimeSlotSelector is updated
    expect(find.byType(TimeSlotSelector), findsOneWidget);
    
    // Find the newly selected duration text (which should be bold)
    final newSelectedDurationFinder = find.text('4 min').evaluate().where((element) {
      final widget = element.widget as Text;
      return widget.style?.fontWeight == FontWeight.bold;
    });
    expect(newSelectedDurationFinder.length, 1);
  });
}
