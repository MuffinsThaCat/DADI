// This is a stub file for web3_service to be used on non-web platforms
// It provides the minimum implementation needed for tests to compile

/// Stub implementation of Web3Service for non-web platforms
class Web3Service {
  /// Singleton instance
  static final Web3Service _instance = Web3Service._internal();

  /// Factory constructor
  factory Web3Service() {
    return _instance;
  }

  /// Internal constructor
  Web3Service._internal();

  /// Stub method for connecting wallet
  Future<void> connectWallet() async {
    // Do nothing in the stub
  }

  /// Stub method for getting wallet address
  String? get walletAddress => '0x0000000000000000000000000000000000000000';

  /// Stub method for getting wallet balance
  double get walletBalance => 0.0;

  /// Stub method for checking if wallet is connected
  bool get isWalletConnected => false;

  /// Stub method for getting wallet connection stream
  Stream<bool> get walletConnectionStream => Stream.value(false);

  /// Stub method for getting wallet balance stream
  Stream<double> get walletBalanceStream => Stream.value(0.0);

  /// Stub method for getting wallet address stream
  Stream<String?> get walletAddressStream => Stream.value(null);

  /// Stub method for disconnecting wallet
  Future<void> disconnectWallet() async {
    // Do nothing in the stub
  }

  /// Stub method for getting chain id
  int? get chainId => 1;

  /// Stub method for switching chain
  Future<void> switchChain(int chainId) async {
    // Do nothing in the stub
  }

  /// Stub method for getting chain id stream
  Stream<int?> get chainIdStream => Stream.value(1);
}
