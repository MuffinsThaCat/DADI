import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/contracts/meta_transaction_relayer.dart';
import 'package:dadi/services/auction_service_meta.dart';
import 'meta_transaction_service_mock.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;
  late MockMetaTransactionService metaTransactionService;
  late MetaTransactionRelayer relayer;
  late AuctionServiceMeta auctionService;
  
  const mockAuctionContractAddress = '0x1234567890123456789012345678901234567890';
  const mockRelayerContractAddress = '0x0987654321098765432109876543210987654321';
  
  setUp(() {
    walletService = MockWalletService();
    metaTransactionService = MockMetaTransactionService(
      walletService: walletService,
    );
    relayer = MetaTransactionRelayer(
      metaTransactionService: metaTransactionService,
      relayerContractAddress: mockRelayerContractAddress,
    );
    auctionService = AuctionServiceMeta(
      relayer: relayer,
      walletService: walletService,
      auctionContractAddress: mockAuctionContractAddress,
    );
  });
  
  group('Meta-transaction tests', () {
    test('Should fail to place bid when wallet is locked', () async {
      // Ensure wallet is locked
      expect(walletService.isUnlocked, false);
      
      // Attempt to place bid
      expect(
        () => auctionService.placeBid(
          deviceId: '0x1234',
          bidAmount: 1.0,
        ),
        throwsException,
      );
    });
    
    test('Should successfully place bid via meta-transaction', () async {
      // Create and unlock wallet
      await walletService.createWallet(password: 'password123');
      await walletService.unlockWallet(password: 'password123');
      
      // Ensure wallet is unlocked
      expect(walletService.isUnlocked, true);
      
      // Place bid
      final txHash = await auctionService.placeBid(
        deviceId: '0x1234',
        bidAmount: 1.0,
      );
      
      // Verify transaction hash format
      expect(txHash, startsWith('0x'));
      expect(txHash.length, greaterThan(10));
    });
    
    test('Should successfully finalize auction via meta-transaction', () async {
      // Create and unlock wallet
      await walletService.createWallet(password: 'password123');
      await walletService.unlockWallet(password: 'password123');
      
      // Finalize auction
      final txHash = await auctionService.finalizeAuction(
        deviceId: '0x1234',
      );
      
      // Verify transaction hash format
      expect(txHash, startsWith('0x'));
      expect(txHash.length, greaterThan(10));
    });
    
    test('Should successfully create auction via meta-transaction', () async {
      // Create and unlock wallet
      await walletService.createWallet(password: 'password123');
      await walletService.unlockWallet(password: 'password123');
      
      // Create auction
      final txHash = await auctionService.createAuction(
        deviceId: '0x5678',
        reservePrice: 0.5,
        duration: 86400, // 1 day in seconds
      );
      
      // Verify transaction hash format
      expect(txHash, startsWith('0x'));
      expect(txHash.length, greaterThan(10));
    });
    
    test('Should successfully cancel auction via meta-transaction', () async {
      // Create and unlock wallet
      await walletService.createWallet(password: 'password123');
      await walletService.unlockWallet(password: 'password123');
      
      // Cancel auction
      final txHash = await auctionService.cancelAuction(
        deviceId: '0x5678',
      );
      
      // Verify transaction hash format
      expect(txHash, startsWith('0x'));
      expect(txHash.length, greaterThan(10));
    });
  });
}
