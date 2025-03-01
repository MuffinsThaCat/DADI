import 'package:dadi/services/web3_service.dart';
import 'package:dadi/models/auction.dart';

/// A utility class to help simulate auction lifecycles in mock mode
class AuctionSimulator {
  final Web3Service _web3Service;

  AuctionSimulator(this._web3Service);

  /// Check if simulation is available (only in mock mode)
  bool get isSimulationAvailable => _web3Service.isMockMode;

  /// Simulate a complete auction lifecycle
  /// 
  /// This will:
  /// 1. Create a new auction
  /// 2. Simulate multiple bids
  /// 3. Fast-forward time to end the auction
  /// 4. Finalize the auction
  /// 
  /// Returns the simulation results including bid history
  Future<Map<String, dynamic>?> simulateCompleteAuction({
    required String deviceId,
    Duration auctionDuration = const Duration(hours: 2),
    double startingBid = 0.1,
    int numberOfBids = 5,
  }) async {
    if (!isSimulationAvailable) {
      throw Exception('Auction simulation is only available in mock mode');
    }

    final result = await _web3Service.simulateAuctionLifecycle(
      deviceId: deviceId,
      auctionDuration: auctionDuration,
      startingBid: startingBid,
      numberOfBids: numberOfBids,
    );

    if (!result.success) {
      throw Exception('Auction simulation failed: ${result.message}');
    }

    return result.data;
  }

  /// Get the auction after simulation
  Future<Auction?> getSimulatedAuction(String deviceId) async {
    final result = await _web3Service.getAuction(deviceId: deviceId);
    if (!result.success) {
      return null;
    }
    return result.data;
  }

  /// Generate a unique device ID for simulation
  String generateUniqueDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'sim-device-$timestamp';
  }

  /// Simulate multiple auctions at once
  Future<List<Map<String, dynamic>>> simulateMultipleAuctions(int count) async {
    if (!isSimulationAvailable) {
      throw Exception('Auction simulation is only available in mock mode');
    }

    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < count; i++) {
      final deviceId = generateUniqueDeviceId();
      
      // Vary the parameters for each auction to create diversity
      final duration = Duration(hours: 1 + i);
      final startingBid = 0.05 * (i + 1);
      final bids = 3 + i;

      final result = await _web3Service.simulateAuctionLifecycle(
        deviceId: deviceId,
        auctionDuration: duration,
        startingBid: startingBid,
        numberOfBids: bids,
      );

      if (result.success && result.data != null) {
        results.add(result.data!);
      }
    }

    return results;
  }
}
