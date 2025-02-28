import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import '../models/wallet_transaction.dart';
import '../utils/crypto_utils.dart';
import 'wallet_service_interface.dart';

/// Mobile implementation of WalletService
class WalletServiceMobile extends WalletServiceInterface {
  // Constants
  static const String _walletAddressKey = 'wallet_address';
  static const String _walletPrivateKeyKey = 'wallet_private_key';
  static const String _walletMnemonicKey = 'wallet_mnemonic';
  static const String _walletPasswordHashKey = 'wallet_password_hash';
  
  // Dependencies
  final FlutterSecureStorage _secureStorage;
  final Web3Client _web3client;
  
  // State
  bool _isUnlocked = false;
  String? _currentAddress;
  EthPrivateKey? _credentials;
  
  // Constructor
  WalletServiceMobile({required String rpcUrl})
      : _secureStorage = const FlutterSecureStorage(),
        _web3client = Web3Client(rpcUrl, Client());
  
  // Factory constructor with default RPC URL
  factory WalletServiceMobile.withDefaultRpc() {
    return WalletServiceMobile(rpcUrl: 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY');
  }
  
  @override
  bool get isCreated => _currentAddress != null;
  
  @override
  bool get isUnlocked => _isUnlocked;
  
  @override
  String? get currentAddress => _currentAddress;
  
  @override
  Future<double> get balance async {
    if (_currentAddress == null || !_isUnlocked) {
      return 0.0;
    }
    
    try {
      final address = EthereumAddress.fromHex(_currentAddress!);
      final balanceInWei = await _web3client.getBalance(address);
      return balanceInWei.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 0.0;
    }
  }
  
  @override
  Future<String> createWallet({required String password}) async {
    try {
      // Generate mnemonic
      final mnemonic = bip39.generateMnemonic();
      
      // Derive private key from mnemonic
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath("m/44'/60'/0'/0/0");
      final privateKey = HEX.encode(child.privateKey!);
      
      // Create credentials and get address
      _credentials = EthPrivateKey.fromHex(privateKey);
      final address = _credentials!.address;
      _currentAddress = address.hexEip55;
      
      // Encrypt sensitive data
      final encryptedMnemonic = CryptoUtils.encryptData(mnemonic, password);
      final encryptedPrivateKey = CryptoUtils.encryptData(privateKey, password);
      final passwordHash = CryptoUtils.hashPassword(password);
      
      // Store encrypted data
      await _secureStorage.write(key: _walletMnemonicKey, value: encryptedMnemonic);
      await _secureStorage.write(key: _walletPrivateKeyKey, value: encryptedPrivateKey);
      await _secureStorage.write(key: _walletAddressKey, value: _currentAddress);
      await _secureStorage.write(key: _walletPasswordHashKey, value: passwordHash);
      
      _isUnlocked = true;
      notifyListeners();
      
      return _currentAddress!;
    } catch (e) {
      debugPrint('Error creating wallet: $e');
      throw Exception('Failed to create wallet: ${e.toString()}');
    }
  }
  
  @override
  Future<bool> unlockWallet({required String password}) async {
    try {
      // Check if wallet exists
      final address = await _secureStorage.read(key: _walletAddressKey);
      if (address == null) {
        return false;
      }
      
      // Verify password
      final storedHash = await _secureStorage.read(key: _walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        return false;
      }
      
      // Get encrypted private key
      final encryptedPrivateKey = await _secureStorage.read(key: _walletPrivateKeyKey);
      if (encryptedPrivateKey == null) {
        return false;
      }
      
      // Decrypt private key
      final privateKey = CryptoUtils.decryptData(encryptedPrivateKey, password);
      
      // Create credentials
      _credentials = EthPrivateKey.fromHex(privateKey);
      final extractedAddress = _credentials!.address;
      
      // Verify address matches
      if (extractedAddress.hexEip55 != address) {
        return false;
      }
      
      _currentAddress = address;
      _isUnlocked = true;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error unlocking wallet: $e');
      return false;
    }
  }
  
  @override
  Future<void> lockWallet() async {
    _isUnlocked = false;
    _credentials = null;
    notifyListeners();
  }
  
  @override
  Future<bool> walletExists() async {
    final address = await _secureStorage.read(key: _walletAddressKey);
    if (address != null) {
      _currentAddress = address;
      notifyListeners();
      return true;
    }
    return false;
  }
  
  @override
  Future<String> importFromMnemonic({
    required String mnemonic,
    required String password,
  }) async {
    try {
      // Validate mnemonic
      if (!bip39.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }
      
      // Derive private key from mnemonic
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath("m/44'/60'/0'/0/0");
      final privateKey = HEX.encode(child.privateKey!);
      
      // Create credentials and get address
      _credentials = EthPrivateKey.fromHex(privateKey);
      final address = _credentials!.address;
      _currentAddress = address.hexEip55;
      
      // Encrypt sensitive data
      final encryptedMnemonic = CryptoUtils.encryptData(mnemonic, password);
      final encryptedPrivateKey = CryptoUtils.encryptData(privateKey, password);
      final passwordHash = CryptoUtils.hashPassword(password);
      
      // Store encrypted data
      await _secureStorage.write(key: _walletMnemonicKey, value: encryptedMnemonic);
      await _secureStorage.write(key: _walletPrivateKeyKey, value: encryptedPrivateKey);
      await _secureStorage.write(key: _walletAddressKey, value: _currentAddress);
      await _secureStorage.write(key: _walletPasswordHashKey, value: passwordHash);
      
      _isUnlocked = true;
      notifyListeners();
      
      return _currentAddress!;
    } catch (e) {
      debugPrint('Error importing wallet from mnemonic: $e');
      throw Exception('Failed to import wallet: ${e.toString()}');
    }
  }
  
  @override
  Future<String> importFromPrivateKey({
    required String privateKey,
    required String password,
  }) async {
    try {
      // Validate private key format
      if (!privateKey.startsWith('0x')) {
        privateKey = '0x$privateKey';
      }
      
      if (privateKey.startsWith('0x')) {
        privateKey = privateKey.substring(2);
      }
      
      // Create credentials and get address
      _credentials = EthPrivateKey.fromHex(privateKey);
      final address = _credentials!.address;
      _currentAddress = address.hexEip55;
      
      // Generate mnemonic (not possible from private key, so we create a new one)
      final mnemonic = bip39.generateMnemonic();
      
      // Encrypt sensitive data
      final encryptedMnemonic = CryptoUtils.encryptData(mnemonic, password);
      final encryptedPrivateKey = CryptoUtils.encryptData(privateKey, password);
      final passwordHash = CryptoUtils.hashPassword(password);
      
      // Store encrypted data
      await _secureStorage.write(key: _walletMnemonicKey, value: encryptedMnemonic);
      await _secureStorage.write(key: _walletPrivateKeyKey, value: encryptedPrivateKey);
      await _secureStorage.write(key: _walletAddressKey, value: _currentAddress);
      await _secureStorage.write(key: _walletPasswordHashKey, value: passwordHash);
      
      _isUnlocked = true;
      notifyListeners();
      
      return _currentAddress!;
    } catch (e) {
      debugPrint('Error importing wallet from private key: $e');
      throw Exception('Failed to import wallet: ${e.toString()}');
    }
  }
  
  @override
  Future<String> exportMnemonic({required String password}) async {
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Verify password
      final storedHash = await _secureStorage.read(key: _walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        throw Exception('Invalid password');
      }
      
      // Get encrypted mnemonic
      final encryptedMnemonic = await _secureStorage.read(key: _walletMnemonicKey);
      if (encryptedMnemonic == null) {
        throw Exception('Mnemonic not found');
      }
      
      // Decrypt mnemonic
      return CryptoUtils.decryptData(encryptedMnemonic, password);
    } catch (e) {
      debugPrint('Error exporting mnemonic: $e');
      throw Exception('Failed to export mnemonic: ${e.toString()}');
    }
  }
  
  @override
  Future<String> exportPrivateKey({required String password}) async {
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Verify password
      final storedHash = await _secureStorage.read(key: _walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        throw Exception('Invalid password');
      }
      
      // Get encrypted private key
      final encryptedPrivateKey = await _secureStorage.read(key: _walletPrivateKeyKey);
      if (encryptedPrivateKey == null) {
        throw Exception('Private key not found');
      }
      
      // Decrypt private key
      return CryptoUtils.decryptData(encryptedPrivateKey, password);
    } catch (e) {
      debugPrint('Error exporting private key: $e');
      throw Exception('Failed to export private key: ${e.toString()}');
    }
  }
  
  @override
  Future<String> sendTransaction({
    required String toAddress,
    required double amount,
    double? gasPrice,
  }) async {
    if (!_isUnlocked || _credentials == null) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Convert to wei
      final amountInWei = EtherAmount.fromBigInt(
        EtherUnit.ether, 
        BigInt.from(amount * 1e18)
      );
      
      // Get gas price if not provided
      final gasPriceInWei = gasPrice != null
          ? EtherAmount.fromBigInt(
              EtherUnit.gwei,
              BigInt.from(gasPrice * 1e9)
            )
          : await _web3client.getGasPrice();
      
      // Create transaction
      final transaction = Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: amountInWei,
        gasPrice: gasPriceInWei,
      );
      
      // Sign and send transaction
      final txHash = await _web3client.sendTransaction(
        _credentials!,
        transaction,
        chainId: 1, // Mainnet
      );
      
      return txHash;
    } catch (e) {
      debugPrint('Error sending transaction: $e');
      throw Exception('Failed to send transaction: ${e.toString()}');
    }
  }
  
  @override
  Future<String> callContract({
    required String contractAddress,
    required String functionName,
    required List<dynamic> parameters,
    double? value,
  }) async {
    if (!_isUnlocked || _credentials == null) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Load contract ABI (this would need to be provided or stored)
      final contractAbi = ContractAbi.fromJson('[]', 'Contract');
      
      // Create contract instance
      final contract = DeployedContract(
        contractAbi,
        EthereumAddress.fromHex(contractAddress),
      );
      
      // Find function
      final function = contract.function(functionName);
      
      // Prepare transaction data
      final valueAmount = value != null 
          ? EtherAmount.fromBigInt(
              EtherUnit.ether, 
              BigInt.from(value * 1e18)
            )
          : null;
      
      final transaction = Transaction.callContract(
        contract: contract,
        function: function,
        parameters: parameters,
        value: valueAmount,
      );
      
      // Send transaction
      final txHash = await _web3client.sendTransaction(
        _credentials!,
        transaction,
        chainId: 1, // Mainnet
      );
      
      return txHash;
    } catch (e) {
      debugPrint('Error calling contract: $e');
      throw Exception('Failed to call contract: ${e.toString()}');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    if (_currentAddress == null) {
      return [];
    }
    
    // Note: This is a placeholder. In a real implementation, you would:
    // 1. Use an Etherscan API or similar service to get transaction history
    // 2. Parse the response into WalletTransaction objects
    // 3. Return the list of transactions
    
    // For now, we'll return a mock list
    return [
      {
        'hash': '0x123456789abcdef',
        'from': _currentAddress!,
        'to': '0xRecipientAddress',
        'value': 0.1,
        'gasPrice': 20.0,
        'gasUsed': 21000,
        'status': TransactionStatus.confirmed.index,
        'type': TransactionType.send.index,
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'blockNumber': 12345678,
      }
    ];
  }
  
  @override
  Future<void> resetWallet() async {
    await _secureStorage.delete(key: _walletAddressKey);
    await _secureStorage.delete(key: _walletPrivateKeyKey);
    await _secureStorage.delete(key: _walletMnemonicKey);
    await _secureStorage.delete(key: _walletPasswordHashKey);
    
    _currentAddress = null;
    _credentials = null;
    _isUnlocked = false;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _web3client.dispose();
    super.dispose();
  }
}
