import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'wallet_service_interface.dart';
import 'transaction_websocket_service.dart';

/// Service for handling gasless meta-transactions on Avalanche
/// This allows users to interact with smart contracts without paying gas fees
/// Based on Avalanche EVM Gasless Transaction implementation
class MetaTransactionService {
  final String _relayerUrl;
  final WalletServiceInterface _walletService;
  final TransactionWebSocketService? _webSocketService;
  
  // Avalanche C-Chain ID
  static const int _avalancheCChainId = 43114; // 0xa86a in hex
  
  // Default gas limit for meta-transactions
  static const int _defaultGasLimit = 500000;
  
  /// Constructor
  MetaTransactionService({
    required String relayerUrl,
    required WalletServiceInterface walletService,
    TransactionWebSocketService? webSocketService,
  }) : _relayerUrl = relayerUrl,
       _walletService = walletService,
       _webSocketService = webSocketService;
  
  /// Get the WebSocket service instance
  TransactionWebSocketService? get webSocketService => _webSocketService;
  
  /// Execute a meta-transaction through a relayer
  /// The relayer will pay the gas fees on behalf of the user
  Future<String> executeMetaTransaction({
    required String trustedForwarderAddress,
    required String contractAddress,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String domainName,
    required String domainVersion,
    String? typeName,
    String? typeSuffixData,
    int? nonce,
    int? gasLimit,
    int? validUntilTime,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (!_walletService.isUnlocked) {
      throw Exception('Wallet must be unlocked to execute meta-transactions');
    }
    
    final userAddress = _walletService.currentAddress;
    if (userAddress == null) {
      throw Exception('No wallet address available');
    }
    
    try {
      // Get nonce if not provided
      final actualNonce = nonce ?? await _getNonce(userAddress, trustedForwarderAddress);
      
      // Prepare function data
      final functionData = _encodeFunctionCall(functionSignature, functionParams);
      
      // Prepare meta-transaction data according to Avalanche's implementation
      final metaTxData = {
        'from': userAddress,
        'to': contractAddress,
        'value': '0x0', // No value transfer
        'gas': '0x${(gasLimit ?? _defaultGasLimit).toRadixString(16)}',
        'nonce': '0x${actualNonce.toRadixString(16)}',
        'data': functionData,
        'validUntilTime': validUntilTime != null 
            ? '0x${validUntilTime.toRadixString(16)}'
            : '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', // Max uint256
      };
      
      // Create typed data for EIP-712 signing
      final typedData = _createTypedData(
        metaTxData, 
        trustedForwarderAddress,
        domainName,
        domainVersion,
        typeName ?? 'my type name',
        typeSuffixData ?? 'bytes8 typeSuffixDatadatadatada)',
      );
      
      // Sign the typed data
      final signature = await _walletService.signTypedData(typedData: typedData);
      
      // Format the request according to Avalanche's gas relayer expectations
      final request = {
        'forwardRequest': {
          'domain': typedData['domain'],
          'types': typedData['types'],
          'primaryType': typedData['primaryType'],
          'message': metaTxData,
        },
        'metadata': {
          'signature': signature,
        },
      };
      
      // Send the meta-transaction to the relayer
      final response = await http.post(
        Uri.parse('$_relayerUrl/rpc-sync'), // Avalanche relayer endpoint
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Relayer error: ${response.body}');
      }
      
      final responseData = jsonDecode(response.body);
      final txHash = responseData['txHash'];
      
      // If WebSocket service is available, register for transaction updates
      if (_webSocketService != null && onStatusUpdate != null) {
        await _webSocketService!.initialize();
        _webSocketService!.watchTransaction(txHash, onStatusUpdate);
      }
      
      return txHash;
    } catch (e) {
      debugPrint('Error executing meta-transaction: $e');
      throw Exception('Failed to execute meta-transaction: ${e.toString()}');
    }
  }
  
  /// Get transaction status updates for a specific transaction
  /// Returns null if WebSocket service is not available
  Stream<TransactionStatusUpdate>? getTransactionStatusStream(String txHash) {
    if (_webSocketService == null) {
      return null;
    }
    
    // Create a stream controller for transaction updates
    final controller = StreamController<TransactionStatusUpdate>();
    
    // Initialize WebSocket service and register for updates
    _webSocketService!.initialize().then((_) {
      _webSocketService!.watchTransaction(txHash, (update) {
        controller.add(update);
        
        // Close the controller when transaction is confirmed or failed
        if (update.status == TransactionStatus.confirmed || 
            update.status == TransactionStatus.failed ||
            update.status == TransactionStatus.dropped) {
          controller.close();
          _webSocketService!.unwatchTransaction(txHash);
        }
      });
    });
    
    // Return the stream
    return controller.stream;
  }
  
  /// Get transaction status updates for all transactions from a specific user
  /// Returns null if WebSocket service is not available
  Stream<TransactionStatusUpdate>? getUserTransactionStatusStream(String userAddress) {
    if (_webSocketService == null) {
      return null;
    }
    
    // Create a stream controller for transaction updates
    final controller = StreamController<TransactionStatusUpdate>();
    
    // Initialize WebSocket service and register for updates
    _webSocketService!.initialize().then((_) {
      _webSocketService!.watchUserTransactions(userAddress, (update) {
        controller.add(update);
      });
    });
    
    // Return the stream
    return controller.stream;
  }
  
  /// Get the current user's address
  Future<String?> getUserAddress() async {
    if (!_walletService.isUnlocked) {
      return null;
    }
    return _walletService.currentAddress;
  }
  
  /// Stop watching a specific transaction
  void unwatchTransaction(String txHash) {
    _webSocketService?.unwatchTransaction(txHash);
  }
  
  /// Stop watching all transactions for a specific user
  void unwatchUserTransactions(String userAddress) {
    _webSocketService?.unwatchUserTransactions(userAddress);
  }
  
  /// Get the current nonce for a user on a specific contract
  Future<int> _getNonce(String userAddress, String trustedForwarderAddress) async {
    try {
      // For Avalanche's implementation, we need to get the nonce from the forwarder contract
      // This is a simplified implementation - in production, you would make an eth_call to the forwarder
      final response = await http.get(
        Uri.parse('$_relayerUrl/nonce?address=$userAddress&forwarder=$trustedForwarderAddress'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get nonce from relayer');
      }
      
      final responseData = jsonDecode(response.body);
      return int.parse(responseData['nonce'].toString());
    } catch (e) {
      debugPrint('Error getting nonce: $e');
      throw Exception('Failed to get nonce: ${e.toString()}');
    }
  }
  
  /// Encode function call data
  String _encodeFunctionCall(String functionSignature, List<dynamic> params) {
    // This is a simplified implementation
    // In a real app, you would use proper ABI encoding
    final functionSelector = keccak256(Uint8List.fromList(utf8.encode(functionSignature))).sublist(0, 4);
    final selectorHex = bytesToHex(functionSelector);
    
    // For simplicity, we're just returning the selector
    // In a real implementation, you would encode the parameters as well
    return '0x$selectorHex';
  }
  
  /// Create typed data for EIP-712 signing according to Avalanche's implementation
  Map<String, dynamic> _createTypedData(
    Map<String, dynamic> metaTxData, 
    String trustedForwarderAddress,
    String domainName,
    String domainVersion,
    String typeName,
    String typeSuffixData,
  ) {
    return {
      'types': {
        'EIP712Domain': [
          {'name': 'name', 'type': 'string'},
          {'name': 'version', 'type': 'string'},
          {'name': 'chainId', 'type': 'uint256'},
          {'name': 'verifyingContract', 'type': 'address'},
        ],
        'Message': [
          {'name': 'from', 'type': 'address'},
          {'name': 'to', 'type': 'address'},
          {'name': 'value', 'type': 'uint256'},
          {'name': 'gas', 'type': 'uint256'},
          {'name': 'nonce', 'type': 'uint256'},
          {'name': 'data', 'type': 'bytes'},
          {'name': 'validUntilTime', 'type': 'uint256'},
        ],
      },
      'primaryType': 'Message',
      'domain': {
        'name': domainName,
        'version': domainVersion,
        'chainId': _avalancheCChainId, // Avalanche C-Chain ID
        'verifyingContract': trustedForwarderAddress,
      },
      'message': metaTxData,
    };
  }
}

/// Helper function to convert bytes to hex string
String bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
