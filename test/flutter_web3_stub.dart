// This is a stub file for flutter_web3 to be used on non-web platforms
// It provides the minimum implementation needed for tests to compile

/// Stub implementation of Ethereum for non-web platforms
class Ethereum {
  /// Stub method for checking if ethereum is supported
  static bool get isSupported => false;

  /// Stub method for checking if ethereum is available
  static bool get isAvailable => false;

  /// Stub method for getting ethereum instance
  static dynamic get ethereum => null;

  /// Stub method for getting selected address
  static String? get selectedAddress => null;

  /// Stub method for getting chain id
  static int? get chainId => null;

  /// Stub method for requesting accounts
  static Future<List<String>> requestAccounts() async {
    return [];
  }

  /// Stub method for switching chain
  static Future<void> switchChain(int chainId) async {
    // Do nothing in the stub
  }

  /// Stub method for adding chain
  static Future<void> addChain({
    required int chainId,
    required String chainName,
    required String nativeCurrency,
    required List<String> rpcUrls,
    List<String>? blockExplorerUrls,
    String? iconUrls,
  }) async {
    // Do nothing in the stub
  }
}

/// Stub implementation of Web3Provider for non-web platforms
class Web3Provider {
  /// Constructor
  Web3Provider(dynamic provider);

  /// Stub method for getting signer
  dynamic get signer => null;

  /// Stub method for getting network
  Future<dynamic> get getNetwork async => null;

  /// Stub method for getting block number
  Future<int> get getBlockNumber async => 0;

  /// Stub method for getting gas price
  Future<BigNumber> get getGasPrice async => BigNumber.from(0);

  /// Stub method for getting balance
  Future<BigNumber> getBalance(String address) async {
    return BigNumber.from(0);
  }
}

/// Stub implementation of Contract for non-web platforms
class Contract {
  /// Constructor
  Contract(String address, List<dynamic> abi, dynamic signerOrProvider);

  /// Stub method for calling contract function
  Future<dynamic> call(String functionName, List<dynamic> args) async {
    return null;
  }
}

/// Stub implementation of BigNumber for non-web platforms
class BigNumber {
  /// Constructor
  BigNumber(dynamic value);

  /// Factory method for creating BigNumber from value
  static BigNumber from(dynamic value) {
    return BigNumber(value);
  }

  /// Stub method for converting to string
  @override
  String toString() {
    return '0';
  }
}

/// Stub implementation of WalletConnectProvider for non-web platforms
class WalletConnectProvider {
  /// Constructor
  WalletConnectProvider({required Map<String, dynamic> infuraId});

  /// Stub method for enabling
  Future<List<String>> enable() async {
    return [];
  }

  /// Stub method for disconnecting
  Future<void> disconnect() async {
    // Do nothing in the stub
  }

  /// Stub method for getting accounts
  List<String> get accounts => [];

  /// Stub method for getting chain id
  int get chainId => 1;
}
