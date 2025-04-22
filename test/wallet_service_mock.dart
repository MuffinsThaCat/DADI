import 'dart:async';
import 'dart:typed_data';
import 'package:dadi/services/wallet_service_interface.dart';

/// Transaction status enum for mock service
enum MockTransactionStatus {
  pending,
  confirmed,
  failed,
  dropped
}

/// Mock implementation of WalletService for testing
class MockWalletService extends WalletServiceInterface {
  String? _currentAddress;
  bool _isUnlocked = false;
  bool _walletExists = false;
  double _balance = 1.5; // Mock balance
  final bool delayInitialization;
  final List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  
  // Completer to control when delayed operations complete
  final Completer<void> _delayCompleter = Completer<void>();
  
  // Map to track transaction status changes
  final Map<String, MockTransactionStatus> _transactionStatuses = {};
  
  // Transaction status update callbacks for testing
  final Map<String, Function(String, MockTransactionStatus)> _statusCallbacks = {};
  
  // Error simulation flags
  bool _simulateNetworkError = false;
  bool _simulateInsufficientGas = false;
  bool _simulateTransactionFailure = false;
  int _failureRate = 0; // Percentage chance of transaction failure (0-100)
  
  // P-Chain mock state
  double _stakedAmount = 0.0;
  bool _stakingActive = false;
  double _stakingRewards = 0.0;
  DateTime? _stakingSince;
  int _lockupPeriodDays = 0;
  
  // Creator tiers thresholds
  final List<double> _creatorTierThresholds = [0, 10, 50, 100, 500]; // AVAX amounts
  
  MockWalletService({this.delayInitialization = false}) {
    // Add some mock transactions
    _addMockTransaction(
      hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      from: '0x1234567890123456789012345678901234567890',
      to: '0x0987654321098765432109876543210987654321',
      value: 0.1,
      status: 'confirmed',
      type: 'send',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    );
    
    _addMockTransaction(
      hash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      from: '0x0987654321098765432109876543210987654321',
      to: '0x1234567890123456789012345678901234567890',
      value: 0.2,
      status: 'confirmed',
      type: 'receive',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    );
    
    // If not delaying, complete the completer immediately
    if (!delayInitialization) {
      _delayCompleter.complete();
    }
  }
  
  // Helper method to add a mock transaction with consistent format
  void _addMockTransaction({
    required String hash,
    required String from,
    required String to,
    required double value,
    required String status,
    required String type,
    required DateTime timestamp,
    double gasPrice = 20.0,
    int? blockNumber,
  }) {
    _transactions.add({
      'hash': hash,
      'from': from,
      'to': to,
      'value': value,
      'gasPrice': gasPrice,
      'status': status,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'blockNumber': blockNumber ?? (status == 'confirmed' ? 12345678 : null),
    });
    
    // Set initial status in the status tracker
    _transactionStatuses[hash] = status == 'confirmed' 
        ? MockTransactionStatus.confirmed 
        : MockTransactionStatus.pending;
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
  
  // Helper method for tests to directly set unlocked state
  void unlock() {
    _isUnlocked = true;
    notifyListeners();
  }
  
  @override
  String? get currentAddress => _currentAddress;
  
  @override
  bool get isLoading => _isLoading;
  
  // Helper method for tests to control loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  Future<double> get balance async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    return _balance;
  }
  
  // Helper method to set balance for testing different scenarios
  void setBalance(double newBalance) {
    _balance = newBalance;
    notifyListeners();
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
    
    // Generate a unique transaction hash
    final txHash = '0x${DateTime.now().millisecondsSinceEpoch}abcdef';
    
    // Add transaction to history with pending status
    _addMockTransaction(
      hash: txHash,
      from: _currentAddress!,
      to: toAddress,
      value: amount,
      gasPrice: gasPrice ?? 20.0,
      status: 'pending',
      type: 'send',
      timestamp: DateTime.now(),
    );
    
    // Simulate transaction confirmation after a delay
    _simulateTransactionConfirmation(txHash);
    
    notifyListeners();
    
    return txHash;
  }
  
  // Helper method to simulate transaction confirmation or failure
  void _simulateTransactionConfirmation(String txHash) {
    // Set initial status to pending
    _transactionStatuses[txHash] = MockTransactionStatus.pending;
    
    // Simulate a delayed confirmation or failure
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_shouldSimulateFailure()) {
        // Simulate transaction failure
        MockTransactionStatus failureStatus;
        String failureReason;
        
        if (_simulateNetworkError) {
          failureStatus = MockTransactionStatus.dropped;
          failureReason = 'Network error';
        } else if (_simulateInsufficientGas) {
          failureStatus = MockTransactionStatus.failed;
          failureReason = 'Insufficient gas';
        } else {
          failureStatus = MockTransactionStatus.failed;
          failureReason = 'Transaction reverted';
        }
        
        _updateTransactionStatus(txHash, failureStatus);
        
        // Update the transaction in the history
        for (int i = 0; i < _transactions.length; i++) {
          if (_transactions[i]['hash'] == txHash) {
            _transactions[i] = {
              ..._transactions[i],
              'status': failureStatus == MockTransactionStatus.failed ? 'failed' : 'dropped',
              'error': failureReason,
            };
            break;
          }
        }
      } else {
        // Update the transaction status to confirmed
        _updateTransactionStatus(txHash, MockTransactionStatus.confirmed);
        
        // Update the transaction in the history
        for (int i = 0; i < _transactions.length; i++) {
          if (_transactions[i]['hash'] == txHash) {
            _transactions[i] = {
              ..._transactions[i],
              'status': 'confirmed',
              'blockNumber': 12345678 + _transactions.length,
              'gasUsed': 21000,
            };
            break;
          }
        }
      }
      
      notifyListeners();
    });
  }
  
  // Helper method to check if we should simulate a transaction failure
  bool _shouldSimulateFailure() {
    if (_simulateNetworkError || _simulateInsufficientGas) {
      return true;
    }
    
    if (_simulateTransactionFailure) {
      // Random chance of failure based on failure rate
      return DateTime.now().millisecondsSinceEpoch % 100 < _failureRate;
    }
    
    return false;
  }
  
  // Helper method to update transaction status and notify callbacks
  void _updateTransactionStatus(String txHash, MockTransactionStatus status) {
    _transactionStatuses[txHash] = status;
    
    // Notify any registered callbacks
    if (_statusCallbacks.containsKey(txHash)) {
      _statusCallbacks[txHash]!(txHash, status);
    }
  }
  
  // Method for tests to register for transaction status updates
  void registerTransactionStatusCallback(
    String txHash, 
    Function(String, MockTransactionStatus) callback
  ) {
    _statusCallbacks[txHash] = callback;
  }
  
  // Method for tests to manually set transaction status
  void setTransactionStatus(String txHash, MockTransactionStatus status) {
    _updateTransactionStatus(txHash, status);
    
    // Update the transaction in the history
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i]['hash'] == txHash) {
        String statusStr;
        switch (status) {
          case MockTransactionStatus.pending:
            statusStr = 'pending';
            break;
          case MockTransactionStatus.confirmed:
            statusStr = 'confirmed';
            break;
          case MockTransactionStatus.failed:
            statusStr = 'failed';
            break;
          case MockTransactionStatus.dropped:
            statusStr = 'dropped';
            break;
        }
        
        _transactions[i] = {
          ..._transactions[i],
          'status': statusStr,
          'blockNumber': status == MockTransactionStatus.confirmed 
              ? 12345678 + _transactions.length 
              : null,
        };
        break;
      }
    }
    
    notifyListeners();
  }
  
  // Helper methods for tests to configure error simulation
  void setSimulateNetworkError(bool value) {
    _simulateNetworkError = value;
  }
  
  void setSimulateInsufficientGas(bool value) {
    _simulateInsufficientGas = value;
  }
  
  void setSimulateTransactionFailure(bool value, {int failureRate = 100}) {
    _simulateTransactionFailure = value;
    _failureRate = failureRate.clamp(0, 100);
  }
  
  @override
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    return List.from(_transactions);
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
    _transactionStatuses.clear();
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
      // Check if there's enough balance
      if (value > _balance) {
        throw Exception('Insufficient balance');
      }
      _balance -= value;
      notifyListeners();
    }
    
    // Generate a unique transaction hash
    final txHash = '0x${DateTime.now().millisecondsSinceEpoch}${functionName.hashCode}';
    
    // Add transaction to history with pending status
    _addMockTransaction(
      hash: txHash,
      from: _currentAddress!,
      to: contractAddress,
      value: value ?? 0,
      status: 'pending',
      type: 'contract_call',
      timestamp: DateTime.now(),
    );
    
    // Store function details for testing
    _transactions.last['functionName'] = functionName;
    _transactions.last['parameters'] = parameters;
    
    // Simulate transaction confirmation after a delay
    _simulateTransactionConfirmation(txHash);
    
    return txHash;
  }
  
  @override
  void dispose() {
    // Call super.dispose() as required by @mustCallSuper
    super.dispose();
  }
  
  @override
  Future<double> get pChainStakedAmount async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      return 0.0;
    }
    
    return _stakedAmount;
  }
  
  @override
  Future<bool> get isCreatorStakingActive async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      return false;
    }
    
    return _stakingActive && _stakedAmount > 0;
  }
  
  @override
  Future<double> get stakingRewards async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      return 0.0;
    }
    
    // For testing, we'll simulate some rewards accumulation based on time since staking
    if (_stakingActive && _stakingSince != null) {
      final daysSinceStaking = DateTime.now().difference(_stakingSince!).inDays;
      // Simple 10% APY calculation
      final calculatedRewards = (_stakedAmount * 0.1 * daysSinceStaking / 365);
      return _stakingRewards + calculatedRewards;
    }
    
    return _stakingRewards;
  }
  
  @override
  Future<int> get creatorTier async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      return 0;
    }
    
    // Determine tier based on staked amount
    for (int i = _creatorTierThresholds.length - 1; i >= 0; i--) {
      if (_stakedAmount >= _creatorTierThresholds[i]) {
        return i;
      }
    }
    
    return 0;
  }
  
  @override
  Future<String> stakeForCreator({
    required double amount,
    int? lockupPeriodDays,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    if (_simulateNetworkError) {
      throw Exception('Network error while staking');
    }
    
    if (_shouldSimulateFailure()) {
      throw Exception('Staking transaction failed');
    }
    
    // Check if user has enough balance
    if (amount > _balance) {
      throw Exception('Insufficient balance to stake');
    }
    
    // Simulate transaction
    final txHash = 'p-stake-${DateTime.now().millisecondsSinceEpoch}';
    
    // Reduce balance
    _balance -= amount;
    
    // Update staking state
    _stakedAmount += amount;
    _stakingActive = true;
    
    // Set staking start time if this is initial stake
    if (_stakingSince == null) {
      _stakingSince = DateTime.now();
    }
    
    // Set lockup period if provided
    if (lockupPeriodDays != null) {
      _lockupPeriodDays = lockupPeriodDays;
    }
    
    // Add transaction to history
    _addMockTransaction(
      hash: txHash,
      from: _currentAddress!,
      to: 'P-Chain Staking Contract',
      value: amount,
      status: 'confirmed',
      type: 'stake',
      timestamp: DateTime.now(),
    );
    
    notifyListeners();
    return txHash;
  }
  
  @override
  Future<String> unstakeFromCreator({
    required double amount,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    if (_simulateNetworkError) {
      throw Exception('Network error while unstaking');
    }
    
    if (_shouldSimulateFailure()) {
      throw Exception('Unstaking transaction failed');
    }
    
    // Verify staking status
    if (!_stakingActive) {
      throw Exception('No active staking found');
    }
    
    // Check if enough is staked
    if (amount > _stakedAmount) {
      throw Exception('Requested amount exceeds staked amount');
    }
    
    // Check if in lockup period
    if (_stakingSince != null && _lockupPeriodDays > 0) {
      final daysSinceStaking = DateTime.now().difference(_stakingSince!).inDays;
      if (daysSinceStaking < _lockupPeriodDays) {
        throw Exception('Staking is still in lockup period. Days remaining: ${_lockupPeriodDays - daysSinceStaking}');
      }
    }
    
    // Simulate transaction
    final txHash = 'p-unstake-${DateTime.now().millisecondsSinceEpoch}';
    
    // Update staking state
    _stakedAmount -= amount;
    if (_stakedAmount <= 0) {
      _stakingActive = false;
      _stakingSince = null;
      _lockupPeriodDays = 0;
      _stakedAmount = 0;
    }
    
    // Add funds back to balance
    _balance += amount;
    
    // Add transaction to history
    _addMockTransaction(
      hash: txHash,
      from: 'P-Chain Staking Contract',
      to: _currentAddress!,
      value: amount,
      status: 'confirmed',
      type: 'unstake',
      timestamp: DateTime.now(),
    );
    
    notifyListeners();
    return txHash;
  }
  
  @override
  Future<String> claimStakingRewards() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    if (_simulateNetworkError) {
      throw Exception('Network error while claiming rewards');
    }
    
    if (_shouldSimulateFailure()) {
      throw Exception('Claiming rewards transaction failed');
    }
    
    // Verify staking status
    if (!_stakingActive) {
      throw Exception('No active staking found');
    }
    
    // Get current rewards
    final rewards = await stakingRewards;
    if (rewards <= 0) {
      throw Exception('No rewards available to claim');
    }
    
    // Simulate transaction
    final txHash = 'p-claim-${DateTime.now().millisecondsSinceEpoch}';
    
    // Add rewards to balance
    _balance += rewards;
    _stakingRewards = 0;
    
    // Add transaction to history
    _addMockTransaction(
      hash: txHash,
      from: 'P-Chain Rewards Contract',
      to: _currentAddress!,
      value: rewards,
      status: 'confirmed',
      type: 'claim_rewards',
      timestamp: DateTime.now(),
    );
    
    notifyListeners();
    return txHash;
  }
  
  @override
  Future<Map<String, dynamic>> getCreatorProfile() async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      return {'active': false};
    }
    
    final rewards = await stakingRewards;
    final tier = await creatorTier;
    
    // Calculate remaining lockup days
    int remainingLockupDays = 0;
    if (_stakingSince != null && _lockupPeriodDays > 0) {
      final daysSinceStaking = DateTime.now().difference(_stakingSince!).inDays;
      remainingLockupDays = (_lockupPeriodDays - daysSinceStaking) > 0 
          ? (_lockupPeriodDays - daysSinceStaking) 
          : 0;
    }
    
    // Calculate platform fee reduction based on tier (0.5% per tier)
    final feeReduction = tier * 0.5;
    
    return {
      'active': _stakingActive,
      'address': _currentAddress,
      'stakedAmount': _stakedAmount,
      'rewards': rewards,
      'tier': tier,
      'tierThreshold': tier < _creatorTierThresholds.length - 1 ? _creatorTierThresholds[tier + 1] : null,
      'stakingSince': _stakingSince,
      'lockupPeriod': _lockupPeriodDays,
      'remainingLockupDays': remainingLockupDays,
      'benefits': {
        'feeReduction': feeReduction,
        'priorityAuctions': tier >= 2,
        'customAuctionSettings': tier >= 3,
        'governanceVoting': tier >= 1,
      }
    };
  }
  
  @override
  Future<String> transferBetweenChains({
    required double amount,
    required bool direction,
  }) async {
    if (delayInitialization) {
      await _delayCompleter.future;
    }
    
    if (!_isUnlocked) {
      throw Exception('Wallet is locked');
    }
    
    if (_simulateNetworkError) {
      throw Exception('Network error during chain transfer');
    }
    
    if (_shouldSimulateFailure()) {
      throw Exception('Chain transfer transaction failed');
    }
    
    // Validate amount
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }
    
    // Check balance based on direction
    if (direction) { // C→P transfer (from C-Chain to P-Chain)
      if (amount > _balance) {
        throw Exception('Insufficient C-Chain balance');
      }
      
      _balance -= amount;
      _stakedAmount += amount;
    } else { // P→C transfer (from P-Chain to C-Chain)
      if (amount > _stakedAmount) {
        throw Exception('Insufficient P-Chain balance');
      }
      
      _stakedAmount -= amount;
      _balance += amount;
      
      if (_stakedAmount <= 0) {
        _stakingActive = false;
        _stakingSince = null;
        _lockupPeriodDays = 0;
        _stakedAmount = 0;
      }
    }
    
    // Simulate transaction
    final txHash = direction 
        ? 'c2p-transfer-${DateTime.now().millisecondsSinceEpoch}'
        : 'p2c-transfer-${DateTime.now().millisecondsSinceEpoch}';
    
    // Add transaction to history
    _addMockTransaction(
      hash: txHash,
      from: direction ? 'C-Chain' : 'P-Chain',
      to: direction ? 'P-Chain' : 'C-Chain',
      value: amount,
      status: 'confirmed',
      type: 'chain_transfer',
      timestamp: DateTime.now(),
    );
    
    notifyListeners();
    return txHash;
  }
  
  // Test helpers for P-Chain functionality
  void setStakedAmount(double amount) {
    _stakedAmount = amount;
    notifyListeners();
  }
  
  void setStakingActive(bool active) {
    _stakingActive = active;
    notifyListeners();
  }
  
  void setStakingRewards(double rewards) {
    _stakingRewards = rewards;
    notifyListeners();
  }
  
  void setStakingSince(DateTime stakingSince) {
    _stakingSince = stakingSince;
    notifyListeners();
  }
  
  void setLockupPeriod(int days) {
    _lockupPeriodDays = days;
    notifyListeners();
  }
}
