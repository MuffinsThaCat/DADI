import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../utils/crypto_utils.dart';
import 'wallet_service_interface.dart';

/// Web implementation of WalletService
class WalletServiceWeb extends WalletServiceInterface {
  // Constants
  static const String _walletAddressKey = 'wallet_address_web';
  static const String _walletPrivateKeyKey = 'wallet_private_key_web';
  static const String _walletMnemonicKey = 'wallet_mnemonic_web';
  static const String _walletPasswordHashKey = 'wallet_password_hash_web';
  
  // P-Chain constants
  static const String _stakedAmountKey = 'staked_amount_web';
  static const String _stakingRewardsKey = 'staking_rewards_web';
  static const String _stakingStatusKey = 'staking_status_web';
  static const String _stakingStartTimeKey = 'staking_start_time_web';
  static const String _stakingLockupPeriodKey = 'staking_lockup_period_web';
  
  // Creator tiers configuration
  static const List<double> _creatorTierThresholds = [0, 10, 50, 100, 500]; // AVAX amounts
  
  // Dependencies
  final Web3Client _web3client;
  late SharedPreferences _prefs;
  bool _prefsInitialized = false;
  
  // State
  bool _isUnlocked = false;
  String? _currentAddress;
  EthPrivateKey? _credentials;
  bool _isLoading = false;
  
  // Constructor
  WalletServiceWeb({required String rpcUrl})
      : _web3client = Web3Client(rpcUrl, Client()) {
    _initPrefs();
  }
  
  // Initialize SharedPreferences
  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsInitialized = true;
      
      // Check if wallet exists
      final address = _prefs.getString(_walletAddressKey);
      if (address != null) {
        _currentAddress = address;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing SharedPreferences: $e');
      debugPrint('Stack trace: $stackTrace');
      _prefsInitialized = false;
      throw Exception('Failed to initialize wallet storage: $e');
    }
  }
  
  // Ensure prefs are initialized
  Future<void> _ensurePrefsInitialized() async {
    if (!_prefsInitialized) {
      await _initPrefs();
    }
  }
  
  @override
  bool get isCreated => _currentAddress != null;
  
  @override
  bool get isUnlocked => _isUnlocked;
  
  @override
  String? get currentAddress => _currentAddress;
  
  @override
  bool get isLoading => _isLoading;
  
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
    await _ensurePrefsInitialized();
    
    try {
      // Generate mnemonic
      final mnemonic = bip39.generateMnemonic();
      
      // Generate private key (simplified for web)
      final privateKey = EthPrivateKey.createRandom(math.Random.secure()).privateKey;
      final privateKeyHex = bytesToHex(privateKey);
      
      // Create credentials and get address
      _credentials = EthPrivateKey.fromHex(privateKeyHex);
      final address = _credentials!.address;
      _currentAddress = address.hexEip55;
      
      // Encrypt sensitive data
      final encryptedMnemonic = CryptoUtils.encryptData(mnemonic, password);
      final encryptedPrivateKey = CryptoUtils.encryptData(privateKeyHex, password);
      final passwordHash = CryptoUtils.hashPassword(password);
      
      // Store encrypted data
      await _prefs.setString(_walletMnemonicKey, encryptedMnemonic);
      await _prefs.setString(_walletPrivateKeyKey, encryptedPrivateKey);
      await _prefs.setString(_walletAddressKey, _currentAddress!);
      await _prefs.setString(_walletPasswordHashKey, passwordHash);
      
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
    await _ensurePrefsInitialized();
    
    try {
      // Check if wallet exists
      final address = _prefs.getString(_walletAddressKey);
      if (address == null) {
        return false;
      }
      
      // Verify password
      final storedHash = _prefs.getString(_walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        return false;
      }
      
      // Get encrypted private key
      final encryptedPrivateKey = _prefs.getString(_walletPrivateKeyKey);
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
    try {
      await _ensurePrefsInitialized();
      
      final address = _prefs.getString(_walletAddressKey);
      if (address != null) {
        _currentAddress = address;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('Error in walletExists: $e');
      debugPrint('Stack trace: $stackTrace');
      // Rethrow with more context
      throw Exception('Failed to check wallet existence: $e');
    }
  }
  
  @override
  Future<String> importFromMnemonic({
    required String mnemonic,
    required String password,
  }) async {
    await _ensurePrefsInitialized();
    
    try {
      // Validate mnemonic
      if (!bip39.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }
      
      // Generate private key (simplified for web)
      final privateKey = EthPrivateKey.createRandom(math.Random.secure()).privateKey;
      final privateKeyHex = bytesToHex(privateKey);
      
      // Create credentials and get address
      _credentials = EthPrivateKey.fromHex(privateKeyHex);
      final address = _credentials!.address;
      _currentAddress = address.hexEip55;
      
      // Encrypt sensitive data
      final encryptedMnemonic = CryptoUtils.encryptData(mnemonic, password);
      final encryptedPrivateKey = CryptoUtils.encryptData(privateKeyHex, password);
      final passwordHash = CryptoUtils.hashPassword(password);
      
      // Store encrypted data
      await _prefs.setString(_walletMnemonicKey, encryptedMnemonic);
      await _prefs.setString(_walletPrivateKeyKey, encryptedPrivateKey);
      await _prefs.setString(_walletAddressKey, _currentAddress!);
      await _prefs.setString(_walletPasswordHashKey, passwordHash);
      
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
    await _ensurePrefsInitialized();
    
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
      await _prefs.setString(_walletMnemonicKey, encryptedMnemonic);
      await _prefs.setString(_walletPrivateKeyKey, encryptedPrivateKey);
      await _prefs.setString(_walletAddressKey, _currentAddress!);
      await _prefs.setString(_walletPasswordHashKey, passwordHash);
      
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
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Verify password
      final storedHash = _prefs.getString(_walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        throw Exception('Invalid password');
      }
      
      // Get encrypted mnemonic
      final encryptedMnemonic = _prefs.getString(_walletMnemonicKey);
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
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Verify password
      final storedHash = _prefs.getString(_walletPasswordHashKey);
      if (storedHash == null || !CryptoUtils.verifyPassword(password, storedHash)) {
        throw Exception('Invalid password');
      }
      
      // Get encrypted private key
      final encryptedPrivateKey = _prefs.getString(_walletPrivateKeyKey);
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
  Future<String?> getMnemonic() async {
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked) {
      return null;
    }
    
    try {
      // Get credentials from current session
      if (_credentials == null) {
        return null;
      }
      
      // Get encrypted mnemonic
      final encryptedMnemonic = _prefs.getString(_walletMnemonicKey);
      if (encryptedMnemonic == null) {
        return null;
      }
      
      // We need to use the cached password from memory
      // This is only available when the wallet is unlocked
      final cachedPassword = _getCachedPassword();
      if (cachedPassword == null) {
        return null;
      }
      
      // Decrypt mnemonic
      return CryptoUtils.decryptData(encryptedMnemonic, cachedPassword);
    } catch (e) {
      debugPrint('Error getting mnemonic: $e');
      return null;
    }
  }
  
  @override
  Future<String?> getPrivateKey() async {
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked) {
      return null;
    }
    
    try {
      // Get credentials from current session
      if (_credentials == null) {
        return null;
      }
      
      // Get encrypted private key
      final encryptedPrivateKey = _prefs.getString(_walletPrivateKeyKey);
      if (encryptedPrivateKey == null) {
        return null;
      }
      
      // We need to use the cached password from memory
      // This is only available when the wallet is unlocked
      final cachedPassword = _getCachedPassword();
      if (cachedPassword == null) {
        return null;
      }
      
      // Decrypt private key
      return CryptoUtils.decryptData(encryptedPrivateKey, cachedPassword);
    } catch (e) {
      debugPrint('Error getting private key: $e');
      return null;
    }
  }
  
  // This is a helper method to get the cached password
  // In a real implementation, this would be securely stored in memory
  // For this demo, we'll use a simple approach
  String? _getCachedPassword() {
    // This is a simplified implementation
    // In a real app, you would use a more secure approach
    // like a secure keychain or encrypted storage
    if (!_isUnlocked) {
      return null;
    }
    
    // In a real implementation, you would have a secure way to
    // retrieve the password that was used to unlock the wallet
    // For now, we'll return a placeholder that should be replaced
    // with a proper implementation
    return _getTemporaryUnlockKey();
  }
  
  // This is a temporary method that should be replaced with a proper implementation
  String? _getTemporaryUnlockKey() {
    // In a real implementation, this would be securely stored
    // For demo purposes, we'll use a simple approach
    final encryptedPrivateKey = _prefs.getString(_walletPrivateKeyKey);
    final encryptedMnemonic = _prefs.getString(_walletMnemonicKey);
    
    if (encryptedPrivateKey == null || encryptedMnemonic == null) {
      return null;
    }
    
    // This is just for demo purposes and should be replaced
    // with a proper secure implementation in a real app
    return 'temporary_unlock_key';
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
        'status': 1, // Confirmed
        'type': 0, // Send
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'blockNumber': 12345678,
      }
    ];
  }
  
  @override
  Future<void> resetWallet() async {
    await _ensurePrefsInitialized();
    
    _prefs.remove(_walletAddressKey);
    _prefs.remove(_walletPrivateKeyKey);
    _prefs.remove(_walletMnemonicKey);
    _prefs.remove(_walletPasswordHashKey);
    
    _currentAddress = null;
    _credentials = null;
    _isUnlocked = false;
    
    notifyListeners();
  }
  
  @override
  Future<String> signMessage({required String message}) async {
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked || _credentials == null) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // Convert message to bytes
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      
      // Create Ethereum signed message hash
      // Follows the format: "\x19Ethereum Signed Message:\n" + message.length + message
      final prefix = '\u0019Ethereum Signed Message:\n${messageBytes.length}';
      final prefixBytes = Uint8List.fromList(utf8.encode(prefix));
      
      // Concatenate and hash
      final Uint8List concat = Uint8List(prefixBytes.length + messageBytes.length)
        ..setAll(0, prefixBytes)
        ..setAll(prefixBytes.length, messageBytes);
      final Uint8List hash = CryptoUtils.keccak256(concat);
      
      // Sign the hash
      final signature = _credentials!.signToEcSignature(hash);
      
      // Convert to hex string with 0x prefix
      final r = signature.r.toRadixString(16).padLeft(64, '0');
      final s = signature.s.toRadixString(16).padLeft(64, '0');
      final v = signature.v.toRadixString(16).padLeft(2, '0');
      
      return '0x$r$s$v';
    } catch (e) {
      debugPrint('Error signing message: $e');
      throw Exception('Failed to sign message: ${e.toString()}');
    }
  }
  
  @override
  Future<String> signTypedData({required Map<String, dynamic> typedData}) async {
    await _ensurePrefsInitialized();
    
    if (!_isUnlocked || _credentials == null) {
      throw Exception('Wallet is locked');
    }
    
    try {
      // For EIP-712 typed data signing, we would need a proper implementation
      // that follows the EIP-712 standard. This is a simplified version.
      
      // Convert typed data to JSON string
      final jsonData = jsonEncode(typedData);
      
      // Hash the JSON data
      final dataBytes = Uint8List.fromList(utf8.encode(jsonData));
      final hash = CryptoUtils.keccak256(dataBytes);
      
      // Sign the hash
      final signature = _credentials!.signToEcSignature(hash);
      
      // Convert to hex string with 0x prefix
      final r = signature.r.toRadixString(16).padLeft(64, '0');
      final s = signature.s.toRadixString(16).padLeft(64, '0');
      final v = signature.v.toRadixString(16).padLeft(2, '0');
      
      return '0x$r$s$v';
    } catch (e) {
      debugPrint('Error signing typed data: $e');
      throw Exception('Failed to sign typed data: ${e.toString()}');
    }
  }
  
  /// Computes the Keccak-256 hash of the input
  Uint8List keccak256(Uint8List input) {
    // Use the crypto_utils implementation
    return CryptoUtils.keccak256(input);
  }
  
  /// Helper method to use keccak on ASCII strings
  Uint8List keccakAscii(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    return CryptoUtils.keccak256(bytes);
  }
  
  Future<bool> isValidAddress(String address) async {
    // Implement address validation logic here
    return true;
  }
  
  @override
  Future<double> get pChainStakedAmount async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) return 0.0;
    
    try {
      return _prefs.getDouble(_stakedAmountKey) ?? 0.0;
    } catch (e) {
      debugPrint('Error getting staked amount: $e');
      return 0.0;
    }
  }
  
  @override
  Future<bool> get isCreatorStakingActive async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) return false;
    
    try {
      final status = _prefs.getBool(_stakingStatusKey) ?? false;
      final stakedAmount = await pChainStakedAmount;
      return status && stakedAmount > 0;
    } catch (e) {
      debugPrint('Error checking creator staking status: $e');
      return false;
    }
  }
  
  @override
  Future<double> get stakingRewards async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) return 0.0;
    
    try {
      final rewards = _prefs.getDouble(_stakingRewardsKey) ?? 0.0;
      
      // In a real implementation, you would calculate real-time rewards
      // based on staking duration and amount
      final stakingStartTime = _prefs.getInt(_stakingStartTimeKey) ?? 0;
      if (stakingStartTime > 0) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final stakedDays = (currentTime - stakingStartTime) / (1000 * 60 * 60 * 24);
        final stakedAmount = await pChainStakedAmount;
        
        // Simple rewards calculation - 10% APY
        final calculatedRewards = (stakedAmount * 0.1 * stakedDays / 365);
        return rewards + calculatedRewards;
      }
      
      return rewards;
    } catch (e) {
      debugPrint('Error getting staking rewards: $e');
      return 0.0;
    }
  }
  
  @override
  Future<int> get creatorTier async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) return 0;
    
    try {
      final stakedAmount = await pChainStakedAmount;
      
      // Determine tier based on staked amount
      for (int i = _creatorTierThresholds.length - 1; i >= 0; i--) {
        if (stakedAmount >= _creatorTierThresholds[i]) {
          return i;
        }
      }
      
      return 0;
    } catch (e) {
      debugPrint('Error getting creator tier: $e');
      return 0;
    }
  }
  
  @override
  Future<String> stakeForCreator({
    required double amount,
    int? lockupPeriodDays,
  }) async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) throw Exception('Wallet must be unlocked to stake');
    
    try {
      // Check if user has enough balance
      final currentBalance = await balance;
      if (currentBalance < amount) {
        throw Exception('Insufficient balance to stake');
      }
      
      // Simulate staking transaction - in production, this would interact with P-Chain
      final txId = 'p-' + DateTime.now().millisecondsSinceEpoch.toString() + 
                 '-' + math.Random().nextInt(1000000).toString();
      
      // Update local storage with staking information
      final currentStakedAmount = await pChainStakedAmount;
      final newStakedAmount = currentStakedAmount + amount;
      
      await _prefs.setDouble(_stakedAmountKey, newStakedAmount);
      await _prefs.setBool(_stakingStatusKey, true);
      
      // Set staking start time if this is initial stake
      if (currentStakedAmount <= 0) {
        await _prefs.setInt(_stakingStartTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
      
      // Set lockup period if provided
      if (lockupPeriodDays != null) {
        await _prefs.setInt(_stakingLockupPeriodKey, lockupPeriodDays);
      }
      
      notifyListeners();
      return txId;
    } catch (e) {
      debugPrint('Error staking for creator: $e');
      throw Exception('Failed to stake: ${e.toString()}');
    }
  }
  
  @override
  Future<String> unstakeFromCreator({
    required double amount,
  }) async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) throw Exception('Wallet must be unlocked to unstake');
    
    try {
      // Check staking status
      final isActive = await isCreatorStakingActive;
      if (!isActive) {
        throw Exception('No active staking found');
      }
      
      // Check if enough is staked
      final stakedAmount = await pChainStakedAmount;
      if (stakedAmount < amount) {
        throw Exception('Insufficient staked amount');
      }
      
      // Check lockup period
      final lockupPeriod = _prefs.getInt(_stakingLockupPeriodKey) ?? 0;
      final stakingStartTime = _prefs.getInt(_stakingStartTimeKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final stakedDays = (currentTime - stakingStartTime) / (1000 * 60 * 60 * 24);
      
      if (stakedDays < lockupPeriod) {
        throw Exception('Staking is still in lockup period. Days remaining: ${lockupPeriod - stakedDays.floor()}');
      }
      
      // Simulate unstaking transaction
      final txId = 'p-' + DateTime.now().millisecondsSinceEpoch.toString() + 
                 '-' + math.Random().nextInt(1000000).toString();
      
      // Update staked amount
      final newStakedAmount = stakedAmount - amount;
      await _prefs.setDouble(_stakedAmountKey, newStakedAmount);
      
      // If fully unstaked, reset staking status
      if (newStakedAmount <= 0) {
        await _prefs.setBool(_stakingStatusKey, false);
        await _prefs.setInt(_stakingStartTimeKey, 0);
        await _prefs.setInt(_stakingLockupPeriodKey, 0);
      }
      
      notifyListeners();
      return txId;
    } catch (e) {
      debugPrint('Error unstaking: $e');
      throw Exception('Failed to unstake: ${e.toString()}');
    }
  }
  
  @override
  Future<String> claimStakingRewards() async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) throw Exception('Wallet must be unlocked to claim rewards');
    
    try {
      // Check if staking is active
      final isActive = await isCreatorStakingActive;
      if (!isActive) {
        throw Exception('No active staking found');
      }
      
      // Get current rewards
      final rewards = await stakingRewards;
      if (rewards <= 0) {
        throw Exception('No rewards available to claim');
      }
      
      // Simulate claiming transaction
      final txId = 'p-' + DateTime.now().millisecondsSinceEpoch.toString() + 
                 '-' + math.Random().nextInt(1000000).toString();
      
      // Reset rewards
      await _prefs.setDouble(_stakingRewardsKey, 0.0);
      
      notifyListeners();
      return txId;
    } catch (e) {
      debugPrint('Error claiming rewards: $e');
      throw Exception('Failed to claim rewards: ${e.toString()}');
    }
  }
  
  @override
  Future<Map<String, dynamic>> getCreatorProfile() async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) return {'active': false};
    
    try {
      final stakedAmount = await pChainStakedAmount;
      final isActive = await isCreatorStakingActive;
      final rewards = await stakingRewards;
      final tier = await creatorTier;
      
      final stakingStartTime = _prefs.getInt(_stakingStartTimeKey) ?? 0;
      final lockupPeriod = _prefs.getInt(_stakingLockupPeriodKey) ?? 0;
      
      // Calculate remaining lockup days
      int remainingLockupDays = 0;
      if (stakingStartTime > 0 && lockupPeriod > 0) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final stakedDays = (currentTime - stakingStartTime) / (1000 * 60 * 60 * 24);
        remainingLockupDays = math.max(0, lockupPeriod - stakedDays.floor());
      }
      
      // Calculate platform fee reduction based on tier
      final feeReduction = tier * 0.5; // 0.5% reduction per tier
      
      return {
        'active': isActive,
        'address': _currentAddress,
        'stakedAmount': stakedAmount,
        'rewards': rewards,
        'tier': tier,
        'tierThreshold': tier < _creatorTierThresholds.length - 1 ? _creatorTierThresholds[tier + 1] : null,
        'stakingSince': stakingStartTime > 0 ? DateTime.fromMillisecondsSinceEpoch(stakingStartTime) : null,
        'lockupPeriod': lockupPeriod,
        'remainingLockupDays': remainingLockupDays,
        'benefits': {
          'feeReduction': feeReduction,
          'priorityAuctions': tier >= 2,
          'customAuctionSettings': tier >= 3,
          'governanceVoting': tier >= 1,
        }
      };
    } catch (e) {
      debugPrint('Error getting creator profile: $e');
      return {'active': false, 'error': e.toString()};
    }
  }
  
  @override
  Future<String> transferBetweenChains({
    required double amount,
    required bool direction,
  }) async {
    await _ensurePrefsInitialized();
    if (!_isUnlocked) throw Exception('Wallet must be unlocked to transfer between chains');
    
    try {
      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      
      // Check balance based on direction
      if (direction) { // C→P transfer
        final cChainBalance = await balance;
        if (cChainBalance < amount) {
          throw Exception('Insufficient C-Chain balance');
        }
      } else { // P→C transfer
        final pChainBalance = await pChainStakedAmount;
        if (pChainBalance < amount) {
          throw Exception('Insufficient P-Chain balance');
        }
      }
      
      // Simulate transfer transaction
      final txId = (direction ? 'c2p-' : 'p2c-') + 
                 DateTime.now().millisecondsSinceEpoch.toString() + 
                 '-' + math.Random().nextInt(1000000).toString();
      
      // In a real implementation, this would actually interact with Avalanche's cross-chain transfer mechanism
      
      notifyListeners();
      return txId;
    } catch (e) {
      debugPrint('Error transferring between chains: $e');
      throw Exception('Failed to transfer: ${e.toString()}');
    }
  }
  
  @override
  void dispose() {
    _web3client.dispose();
    super.dispose();
  }
}

/// Utility function to convert bytes to hex string
String bytesToHex(Uint8List bytes) {
  return '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('')}';
}
