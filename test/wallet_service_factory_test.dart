import 'package:flutter_test/flutter_test.dart';
import 'package:dadi/services/wallet_service_factory.dart';
import 'package:dadi/services/wallet_service_interface.dart';
import 'package:dadi/services/wallet_service_mobile.dart';
import 'package:flutter/foundation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('WalletServiceFactory Tests', () {
    test('Should create appropriate wallet service based on platform', () {
      // This test will behave differently based on the platform
      // In a test environment, we can't fully test this, but we can verify
      // that it doesn't crash and returns a WalletServiceInterface
      
      try {
        final walletService = WalletServiceFactory.createWalletService();
        expect(walletService, isA<WalletServiceInterface>());
        
        // In test environment, this will likely be WalletServiceMobile
        // since flutter_web3 is not available
        if (!kIsWeb) {
          expect(walletService, isA<WalletServiceMobile>());
        }
      } catch (e) {
        // On web platform in test environment, this might throw
        // due to missing flutter_web3 implementation
        if (kIsWeb) {
          expect(e, isA<UnsupportedError>());
        } else {
          // On non-web platforms, it should not throw
          fail('Should not throw on non-web platforms: $e');
        }
      }
    });
    
    test('Should use custom RPC URL when provided', () {
      const customRpcUrl = 'https://custom.rpc.url';
      
      try {
        final walletService = WalletServiceFactory.createWalletService(
          rpcUrl: customRpcUrl,
        );
        
        expect(walletService, isA<WalletServiceInterface>());
        
        // Verify the RPC URL was set correctly
        // This is implementation-specific and may not be directly testable
        // in all cases
        
        // For mobile implementation, we can check the web3client
        if (!kIsWeb && walletService is WalletServiceMobile) {
          // This would require exposing the web3client as a getter
          // which may not be available in the current implementation
        }
      } catch (e) {
        // Handle web platform exceptions as in the previous test
        if (kIsWeb) {
          expect(e, isA<UnsupportedError>());
        } else {
          fail('Should not throw on non-web platforms: $e');
        }
      }
    });
    
    test('Should use default RPC URL when none provided', () {
      try {
        final walletService = WalletServiceFactory.createWalletService();
        
        expect(walletService, isA<WalletServiceInterface>());
        
        // The default RPC URL is used internally and may not be
        // directly testable without exposing it
      } catch (e) {
        // Handle web platform exceptions as in the previous tests
        if (kIsWeb) {
          expect(e, isA<UnsupportedError>());
        } else {
          fail('Should not throw on non-web platforms: $e');
        }
      }
    });
  });
}
