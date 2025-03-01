import 'package:mockito/mockito.dart';
import 'package:dadi/services/web3_service.dart';
import 'package:dadi/models/operation_result.dart';
import 'package:dadi/models/auction.dart';

class MockWeb3Service extends Mock implements Web3Service {
  @override
  String get currentAddress => '0xMockAddress';
  
  @override
  bool get isMockMode => true;
  
  @override
  Future<OperationResult<Auction>> getAuction({required String deviceId}) async {
    return super.noSuchMethod(
      Invocation.method(#getAuction, [], {#deviceId: deviceId}),
      returnValue: Future.value(OperationResult<Auction>.success(
        data: Auction(
          deviceId: deviceId,
          owner: '0xTestOwner',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 4)),
          minimumBid: 0.01,
          highestBid: 0.0,
          highestBidder: '',
          isActive: true,
          isFinalized: false,
        ),
      )),
    ) as Future<OperationResult<Auction>>;
  }
  
  @override
  Future<OperationResult<double>> placeBidNew({
    required String deviceId,
    required double amount,
  }) async {
    return super.noSuchMethod(
      Invocation.method(#placeBidNew, [], {#deviceId: deviceId, #amount: amount}),
      returnValue: Future.value(OperationResult<double>.success(
        data: amount,
        message: 'Bid placed successfully',
      )),
    ) as Future<OperationResult<double>>;
  }
  
  @override
  Future<OperationResult<bool>> finalizeAuctionNew({required String deviceId}) async {
    return super.noSuchMethod(
      Invocation.method(#finalizeAuctionNew, [], {#deviceId: deviceId}),
      returnValue: Future.value(OperationResult<bool>.success(
        data: true,
        message: 'Auction finalized successfully',
      )),
    ) as Future<OperationResult<bool>>;
  }
  
  @override
  Future<OperationResult<bool>> cancelAuction({required String deviceId}) async {
    return super.noSuchMethod(
      Invocation.method(#cancelAuction, [], {#deviceId: deviceId}),
      returnValue: Future.value(OperationResult<bool>.success(
        data: true,
        message: 'Auction cancelled successfully',
      )),
    ) as Future<OperationResult<bool>>;
  }
}
