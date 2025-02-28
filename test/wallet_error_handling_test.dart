import 'package:flutter_test/flutter_test.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;

  setUp(() {
    walletService = MockWalletService();
  });

  group('Wallet Error Handling Tests', () {
    test('Should throw when trying to unlock non-existent wallet', () async {
      expect(
        () => walletService.unlockWallet(password: 'password123'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Wallet does not exist'),
        )),
      );
    });

    test('Should throw when trying to unlock with wrong password', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      // Try to unlock with wrong password
      expect(
        () => walletService.unlockWallet(password: 'wrongpassword'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid password'),
        )),
      );
    });

    test('Should throw when trying to send transaction from locked wallet', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      // Try to send transaction
      expect(
        () => walletService.sendTransaction(
          toAddress: '0x0987654321098765432109876543210987654321',
          amount: 0.1,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Wallet is locked'),
        )),
      );
    });

    test('Should throw when trying to send more than balance', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Try to send more than balance
      expect(
        () => walletService.sendTransaction(
          toAddress: '0x0987654321098765432109876543210987654321',
          amount: 100.0, // More than the mock balance of 1.5
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Insufficient balance'),
        )),
      );
    });

    test('Should throw when trying to export mnemonic from locked wallet', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      // Try to export mnemonic
      expect(
        () => walletService.exportMnemonic(password: 'password123'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Wallet is locked'),
        )),
      );
    });

    test('Should throw when trying to export private key from locked wallet', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      // Try to export private key
      expect(
        () => walletService.exportPrivateKey(password: 'password123'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Wallet is locked'),
        )),
      );
    });

    test('Should throw when trying to export with wrong password', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Try to export with wrong password
      expect(
        () => walletService.exportMnemonic(password: 'wrongpassword'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid password'),
        )),
      );
    });

    test('Should throw when trying to get transaction history from locked wallet', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      // Lock wallet
      await walletService.lockWallet();
      
      // Try to get transaction history
      expect(
        () => walletService.getTransactionHistory(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Wallet is locked'),
        )),
      );
    });
  });
}
