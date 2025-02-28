import 'package:flutter_test/flutter_test.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;

  setUp(() {
    walletService = MockWalletService();
  });

  group('WalletService Tests', () {
    test('Initial state should be correct', () async {
      expect(walletService.isCreated, false);
      expect(walletService.isUnlocked, false);
      expect(walletService.currentAddress, null);
      expect(await walletService.balance, 1.5);
    });

    test('Create wallet should set correct state', () async {
      final address = await walletService.createWallet(password: 'password123');
      
      expect(address, '0x1234567890abcdef1234567890abcdef12345678');
      expect(walletService.isCreated, true);
      expect(walletService.isUnlocked, true);
      expect(walletService.currentAddress, '0x1234567890abcdef1234567890abcdef12345678');
    });

    test('Lock and unlock wallet should work correctly', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      expect(walletService.isUnlocked, false);
      
      // Unlock wallet
      final success = await walletService.unlockWallet(password: 'password123');
      expect(success, true);
      expect(walletService.isUnlocked, true);
    });

    test('Import from mnemonic should set correct state', () async {
      const mnemonic = 'test word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';
      final address = await walletService.importFromMnemonic(
        mnemonic: mnemonic,
        password: 'password123',
      );
      
      expect(address, '0x1234567890abcdef1234567890abcdef12345678');
      expect(walletService.isCreated, true);
      expect(walletService.isUnlocked, true);
      expect(walletService.currentAddress, '0x1234567890abcdef1234567890abcdef12345678');
    });

    test('Import from private key should set correct state', () async {
      const privateKey = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final address = await walletService.importFromPrivateKey(
        privateKey: privateKey,
        password: 'password123',
      );
      
      expect(address, '0x1234567890abcdef1234567890abcdef12345678');
      expect(walletService.isCreated, true);
      expect(walletService.isUnlocked, true);
      expect(walletService.currentAddress, '0x1234567890abcdef1234567890abcdef12345678');
    });

    test('Export mnemonic should work when wallet is unlocked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final mnemonic = await walletService.exportMnemonic(password: 'password123');
      expect(mnemonic, 'test word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12');
    });

    test('Export mnemonic should throw when wallet is locked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      expect(
        () => walletService.exportMnemonic(password: 'password123'),
        throwsException,
      );
    });

    test('Export private key should work when wallet is unlocked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final privateKey = await walletService.exportPrivateKey(password: 'password123');
      expect(privateKey, '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    });

    test('Send transaction should update balance', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Initial balance
      expect(await walletService.balance, 1.5);
      
      // Send transaction
      final txHash = await walletService.sendTransaction(
        toAddress: '0xRecipientAddress',
        amount: 0.5,
      );
      
      expect(txHash, isNotEmpty);
      expect(await walletService.balance, 1.0);
    });

    test('Get transaction history should return list', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final transactions = await walletService.getTransactionHistory();
      expect(transactions, isNotEmpty);
      expect(transactions.length, 2);
      
      // Check first transaction
      final firstTx = transactions[0];
      expect(firstTx['hash'], isNotEmpty);
      expect(firstTx['from'], isNotEmpty);
      expect(firstTx['to'], isNotEmpty);
      expect(firstTx['value'], isA<double>());
    });

    test('Reset wallet should clear state', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Reset wallet
      await walletService.resetWallet();
      
      expect(walletService.isCreated, false);
      expect(walletService.isUnlocked, false);
      expect(walletService.currentAddress, null);
      expect(await walletService.balance, 1.5); // Back to initial mock balance
    });
  });
}
