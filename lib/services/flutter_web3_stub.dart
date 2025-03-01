// This is a stub file for flutter_web3 to be used on non-web platforms
// It provides the minimum implementation needed for the code to compile

/// Stub implementation of Ethereum for non-web platforms
class Ethereum {
  /// Stub method for checking if ethereum is supported
  static bool get isSupported => false;

  /// Stub method for checking if ethereum is available
  static bool get isAvailable => false;

  /// Stub method for getting ethereum instance
  static dynamic get ethereum => _StubEthereum();

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

/// Stub implementation of ethereum object
class _StubEthereum {
  Future<List<String>> request(Map<String, dynamic> args) async {
    return [];
  }
}

/// Stub implementation of Provider for non-web platforms
class Provider {
  /// Stub method for getting network
  Future<dynamic> getNetwork() async => {'chainId': 1, 'name': 'Stub Network'};
  
  /// Stub method for getting block number
  Future<int> getBlockNumber() async => 0;
  
  /// Stub method for getting gas price
  Future<BigNumber> getGasPrice() async => BigNumber.from(0);
}

/// Stub implementation of JsonRpcProvider for non-web platforms
class JsonRpcProvider extends Provider {
  /// Constructor
  JsonRpcProvider(String rpcUrl);
  
  /// Stub method for getting signer
  dynamic getSigner() => _StubSigner();
  
  /// Stub method for getting network
  @override
  Future<dynamic> getNetwork() async => {'chainId': 1, 'name': 'Stub Network'};
  
  /// Stub method for getting block number
  @override
  Future<int> getBlockNumber() async => 0;
  
  /// Stub method for getting gas price
  @override
  Future<BigNumber> getGasPrice() async => BigNumber.from(0);
  
  /// Stub method for getting balance
  Future<BigNumber> getBalance(String address) async {
    return BigNumber.from(0);
  }
}

/// Stub implementation of TransactionOverride for non-web platforms
class TransactionOverride {
  /// Constructor
  TransactionOverride({
    BigNumber? gasLimit,
    BigNumber? gasPrice,
    String? from,
    String? to,
    BigNumber? value,
    String? data,
    int? nonce,
  });
}

/// Stub implementation of Web3Provider for non-web platforms
class Web3Provider extends Provider {
  /// Constructor
  Web3Provider(dynamic provider);

  /// Stub method for getting signer
  dynamic getSigner([int? index]) => _StubSigner();

  /// Stub method for getting network
  @override
  Future<dynamic> getNetwork() async => {'chainId': 1, 'name': 'Stub Network'};

  /// Stub method for getting block number
  @override
  Future<int> getBlockNumber() async => 0;

  /// Stub method for getting gas price
  @override
  Future<BigNumber> getGasPrice() async => BigNumber.from(0);

  /// Stub method for getting balance
  Future<BigNumber> getBalance(String address) async {
    return BigNumber.from(0);
  }
}

/// Stub implementation of Signer for non-web platforms
class _StubSigner {
  /// Stub method for getting address
  Future<String> getAddress() async => '0x0000000000000000000000000000000000000000';
  
  /// Stub method for sending transaction
  Future<dynamic> sendTransaction(dynamic transaction) async {
    return {'hash': '0x0000000000000000000000000000000000000000000000000000000000000000'};
  }
}

/// Stub implementation of Contract for non-web platforms
class Contract {
  /// Constructor
  Contract(String address, dynamic abi, dynamic signerOrProvider);
  
  /// Contract address
  String get address => '0x0000000000000000000000000000000000000000';

  /// Stub method for calling contract function
  Future<dynamic> call(String functionName, List<dynamic> args) async {
    return null;
  }
  
  /// Stub method for sending transaction to contract
  Future<dynamic> send(String functionName, List<dynamic> args, [dynamic override]) async {
    return {'hash': '0x0000000000000000000000000000000000000000000000000000000000000000'};
  }
  
  /// Stub method for connecting contract to signer
  Contract connect(dynamic signer) {
    return this;
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
  
  /// Stub method for division
  BigNumber div(dynamic other) {
    return BigNumber.from(0);
  }
  
  /// Stub method for multiplication
  BigNumber mul(dynamic other) {
    return BigNumber.from(0);
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
