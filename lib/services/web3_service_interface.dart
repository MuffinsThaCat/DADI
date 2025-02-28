import 'package:flutter/foundation.dart';
import '../models/auction.dart';
import '../models/operation_result.dart';

/// Abstract interface for Web3Service to support multiple platforms
abstract class Web3ServiceInterface extends ChangeNotifier {
  /// Whether the service is connected to a blockchain
  bool get isConnected;
  
  /// Whether the service is in mock mode
  bool get isMockMode;
  
  /// Initialize the contract
  Future<bool> initializeContract();
  
  /// Connect to the blockchain using JsonRpc
  Future<bool> connectWithJsonRpc();
  
  /// Get an auction by device ID
  Future<OperationResult<Auction>> getAuction({required String deviceId});
  
  /// Get all active auctions
  Future<OperationResult<List<Auction>>> getActiveAuctions();
  
  /// Place a bid on an auction
  Future<OperationResult<bool>> placeBid({
    required String deviceId,
    required double amount,
  });
  
  /// Finalize an auction
  Future<OperationResult<bool>> finalizeAuction({required String deviceId});
}
