import 'package:flutter/foundation.dart';

/// Interface for wallet service to support multiple platforms
abstract class WalletServiceInterface extends ChangeNotifier {
  /// Whether the wallet is created
  bool get isCreated;
  
  /// Whether the wallet is unlocked
  bool get isUnlocked;
  
  /// Current wallet address
  String? get currentAddress;
  
  /// Whether the wallet is currently loading data
  bool get isLoading;
  
  /// Current wallet balance in ETH
  Future<double> get balance;
  
  /// Create a new wallet with password
  Future<String> createWallet({required String password});
  
  /// Unlock the wallet with password
  Future<bool> unlockWallet({required String password});
  
  /// Lock the wallet
  Future<void> lockWallet();
  
  /// Check if wallet exists
  Future<bool> walletExists();
  
  /// Import wallet from mnemonic phrase
  Future<String> importFromMnemonic({
    required String mnemonic,
    required String password,
  });
  
  /// Import wallet from private key
  Future<String> importFromPrivateKey({
    required String privateKey,
    required String password,
  });
  
  /// Export mnemonic phrase (requires password)
  Future<String> exportMnemonic({required String password});
  
  /// Export private key (requires password)
  Future<String> exportPrivateKey({required String password});
  
  /// Get mnemonic phrase (requires wallet to be unlocked)
  Future<String?> getMnemonic();
  
  /// Get private key (requires wallet to be unlocked)
  Future<String?> getPrivateKey();
  
  /// Send ETH to address
  Future<String> sendTransaction({
    required String toAddress,
    required double amount,
    double? gasPrice,
  });
  
  /// Call a contract method
  Future<String> callContract({
    required String contractAddress,
    required String functionName,
    required List<dynamic> parameters,
    double? value,
  });
  
  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory();
  
  /// Reset wallet (delete all data)
  Future<void> resetWallet();
  
  /// Sign a message with the wallet's private key
  /// Returns the signature as a hex string
  Future<String> signMessage({required String message});
  
  /// Sign typed data according to EIP-712 standard
  /// Returns the signature as a hex string
  Future<String> signTypedData({required Map<String, dynamic> typedData});
}
