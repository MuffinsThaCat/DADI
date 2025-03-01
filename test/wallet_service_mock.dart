import 'dart:async';
import 'dart:typed_data';
import 'package:dadi/services/wallet_service_interface.dart';

/// Mock implementation of WalletService for testing
class MockWalletService extends WalletServiceInterface {
  String? _currentAddress;
  bool _isUnlocked = false;
  bool _walletExists = false;
  double _balance = 1.5; // Mock balance
  final bool delayInitialization;
  final List<Map<String, dynamic>> _transactions = [];
  
  // Completer to control when delayed operations complete
  final Completer<void> _delayCompleter = Completer<void>();
  
  MockWalletService({this.delayInitialization = false}) {
    // Add some mock transactions
    _transactions.add({
      'hash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      'from': '0x1234567890123456789012345678901234567890',
      'to': '0x0987654321098765432109876543210987654321',
      'value': 0.1,
      'gasPrice': 20.0,
      'status': 'confirmed',
      'type': 'send',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'blockNumber': 12345678,
    });
    
    _transactions.add({
      'hash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      'from': '0x0987654321098765432109876543210987654321',
      'to': '0x1234567890123456789012345678901234567890',
      'value': 0.2,
      'gasPrice': 20.0,
      'status': 'confirmed',
      'type': 'receive',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'blockNumber': 12345677,
    });
    
    // If not delaying, complete the completer immediately
    if (!delayInitialization) {
      _delayCompleter.complete();
    }
  }
  
  // Helper method to complete delayed operations in tests
  void completeDelay() {
    if (!_delayCompleter.isCompleted) {
      _delayCompleter.complete();
    }
  }
  
  @override
  bool get isCreated => _walletExists;
  
  @override
  bool get isUnlocked => _isUnlocked;
  
  @override
  String? get currentAddress => _currentAddress;
  
  @override
  Future<double> get balance async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    return _balance;
  }
  
  @override
  Future<String> createWallet({required String password}) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    _currentAddress = '0x1234567890abcdef1234567890abcdef12345678';
    _isUnlocked = true;
    _walletExists = true;
    notifyListeners();
    return _currentAddress!;
  }
  
  @override
  Future<bool> unlockWallet({required String password}) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_walletExists) {
      throw Exception('Wallet does not exist');
    }
    
    // Check password (in a real implementation, this would verify against stored credentials)
    if (password != 'password123') {
      throw Exception('Invalid password');
    }
    
    _isUnlocked = true;
    notifyListeners();
    return true;
  }
  
  @override
  Future<void> lockWallet() async {
    _isUnlocked = false;
    notifyListeners();
  }
  
  @override
  Future<bool> walletExists() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    return _walletExists;
  }
  
  // Helper methods for testing
  void unlock() {
    if (!_walletExists) {
      throw Exception('Wallet does not exist');
    }
    _isUnlocked = true;
    notifyListeners();
  }
  
  void setAddress(String address) {
    _currentAddress = address;
    _walletExists = true;
    notifyListeners();
  }
  
  @override
  Future<String> importFromMnemonic({
    required String mnemonic,
    required String password,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    _currentAddress = '0x1234567890abcdef1234567890abcdef12345678';
    _isUnlocked = true;
    _walletExists = true;
    notifyListeners();
    return _currentAddress!;
  }
  
  @override
  Future<String> importFromPrivateKey({
    required String privateKey,
    required String password,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    _currentAddress = '0x1234567890abcdef1234567890abcdef12345678';
    _isUnlocked = true;
    _walletExists = true;
    notifyListeners();
    return _currentAddress!;
  }
  
  @override
  Future<String> exportMnemonic({required String password}) async {
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    // Check password (in a real implementation, this would verify against stored credentials)
    if (password != 'password123') {
      throw Exception('Invalid password');
    }
    
    return 'test word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';
  }
  
  @override
  Future<String> exportPrivateKey({required String password}) async {
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    return '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  }
  
  @override
  Future<String?> getMnemonic() async {
    if (!_isUnlocked) {
      return null;
    }
    
    // Return a mock mnemonic phrase for testing
    return 'test abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  }
  
  @override
  Future<String?> getPrivateKey() async {
    if (!_isUnlocked) {
      return null;
    }
    
    // Return a mock private key for testing
    return '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  }
  
  @override
  Future<String> sendTransaction({
    required String toAddress,
    required double amount,
    double? gasPrice,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    // Check if there's enough balance
    if (amount > _balance) {
      throw Exception('Insufficient balance');
    }
    
    _balance -= amount;
    
    // Add transaction to history
    _transactions.add({
      'hash': '0x${DateTime.now().millisecondsSinceEpoch}',
      'from': _currentAddress!,
      'to': toAddress,
      'value': amount,
      'gasPrice': gasPrice ?? 20.0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    notifyListeners();
    
    return '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  }
  
  @override
  Future<String> callContract({
    required String contractAddress,
    required String functionName,
    required List<dynamic> parameters,
    double? value,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    if (value != null && value > 0) {
      _balance -= value;
      notifyListeners();
    }
    
    // Add transaction to history
    _transactions.add({
      'hash': '0x${DateTime.now().millisecondsSinceEpoch}',
      'from': _currentAddress!,
      'to': contractAddress,
      'value': value ?? 0,
      'gasPrice': 20.0,
      'status': 'pending',
      'type': 'contract_call',
      'timestamp': DateTime.now().toIso8601String(),
      'blockNumber': null,
    });
    
    return '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  }
  
  @override
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    return [
      {
        'hash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'from': '0x1234567890abcdef1234567890abcdef12345678',
        'to': '0xabcdef1234567890abcdef1234567890abcdef12',
        'value': 0.1,
        'gasPrice': 20.0,
        'gasUsed': 21000,
        'status': 1, // TransactionStatus.confirmed
        'type': 0, // TransactionType.send
        'timestamp': DateTime.now().toString(),
        'blockNumber': 12345678
      },
      {
        'hash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'from': '0xabcdef1234567890abcdef1234567890abcdef12',
        'to': '0x1234567890abcdef1234567890abcdef12345678',
        'value': 0.5,
        'gasPrice': 20.0,
        'gasUsed': 21000,
        'status': 1, // TransactionStatus.confirmed
        'type': 1, // TransactionType.receive
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toString(),
        'blockNumber': 12345670
      }
    ];
  }
  
  @override
  Future<void> resetWallet() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    _currentAddress = null;
    _isUnlocked = false;
    _walletExists = false;
    _balance = 1.5; // Reset to initial mock balance
    _transactions.clear();
    notifyListeners();
  }
  
  @override
  Future<String> signMessage({required String message}) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    // Return a mock signature
    return '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00';
  }
  
  @override
  Future<String> signTypedData({required Map<String, dynamic> typedData}) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    // Return a mock signature
    return '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab01';
  }
  
  Future<bool> isValidAddress(String address) async {
    return address.startsWith('0x') && address.length == 42;
  }
  
  /// Computes the Keccak-256 hash of the input
  Uint8List keccak256(Uint8List input) {
    // This is a mock implementation that returns a fixed hash for testing
    return Uint8List.fromList(List.generate(32, (index) => index));
  }
  
  /// Helper method to use keccak on ASCII strings
  Uint8List keccakAscii(String input) {
    // This is a mock implementation that returns a fixed hash for testing
    return Uint8List.fromList(List.generate(32, (index) => index));
  }
  
  @override
  void dispose() {
    // Call super.dispose() as required by @mustCallSuper
    super.dispose();
  }
}
