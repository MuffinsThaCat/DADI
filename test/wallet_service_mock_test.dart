import 'package:flutter_test/flutter_test.dart';
import 'wallet_service_mock.dart';

void main() {
  late MockWalletService walletService;
  
  setUp(() {
    walletService = MockWalletService();
  });
  
  group('MockWalletService Tests', () {
    test('Initial state should be correct', () {
      expect(walletService.isCreated, false);
      expect(walletService.isUnlocked, false);
      expect(walletService.currentAddress, null);
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
      final result = await walletService.unlockWallet(password: 'password123');
      expect(result, true);
      expect(walletService.isUnlocked, true);
    });
    
    test('Import from mnemonic should set correct state', () async {
      const mnemonic = 'test test test test test test test test test test test junk';
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
      expect(mnemonic, isNotEmpty);
      expect(mnemonic.split(' ').length, 13); // 13-word mnemonic in the mock implementation
    });
    
    test('Export private key should work when wallet is unlocked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final privateKey = await walletService.exportPrivateKey(password: 'password123');
      expect(privateKey, isNotEmpty);
      expect(privateKey.startsWith('0x'), true);
    });
    
    test('Send transaction should work when wallet is unlocked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final txHash = await walletService.sendTransaction(
        toAddress: '0x0987654321098765432109876543210987654321',
        amount: 0.1,
      );
      
      expect(txHash, isNotEmpty);
      expect(txHash.startsWith('0x'), true);
    });
    
    test('Call contract should work when wallet is unlocked', () async {
      // Create wallet first
      await walletService.createWallet(password: 'password123');
      
      final txHash = await walletService.callContract(
        contractAddress: '0x0987654321098765432109876543210987654321',
        functionName: 'transfer',
        parameters: ['0x1111111111111111111111111111111111111111', 100],
      );
      
      expect(txHash, isNotEmpty);
      expect(txHash.startsWith('0x'), true);
    });
    
    test('Get transaction history should return list', () async {
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
    
    test('Delayed initialization should work correctly', () async {
      final delayedWalletService = MockWalletService(delayInitialization: true);
      
      // Create wallet with delay
      final createFuture = delayedWalletService.createWallet(password: 'password123');
      
      // At this point, the wallet should not be created yet
      expect(delayedWalletService.isCreated, false);
      expect(delayedWalletService.isUnlocked, false);
      
      // Complete the delay
      delayedWalletService.completeDelay();
      
      // Now the createWallet should complete
      final address = await createFuture;
      
      expect(address, '0x1234567890abcdef1234567890abcdef12345678');
      expect(delayedWalletService.isCreated, true);
      expect(delayedWalletService.isUnlocked, true);
    });
  });
}
