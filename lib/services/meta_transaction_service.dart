import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'wallet_service_interface.dart';

/// Service for handling gasless meta-transactions
/// This allows users to interact with smart contracts without paying gas fees
class MetaTransactionService {
  final String _relayerUrl;
  final WalletServiceInterface _walletService;
  
  /// Constructor
  MetaTransactionService({
    required String relayerUrl,
    required WalletServiceInterface walletService,
  }) : _relayerUrl = relayerUrl,
       _walletService = walletService;
  
  /// Execute a meta-transaction through a relayer
  /// The relayer will pay the gas fees on behalf of the user
  Future<String> executeMetaTransaction({
    required String contractAddress,
    required String functionSignature,
    required List<dynamic> functionParams,
    int? nonce,
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
      final actualNonce = nonce ?? await _getNonce(userAddress, contractAddress);
      
      // Prepare function data
      final functionData = _encodeFunctionCall(functionSignature, functionParams);
      
      // Prepare meta-transaction data
      final metaTxData = {
        'from': userAddress,
        'to': contractAddress,
        'nonce': actualNonce,
        'data': functionData,
      };
      
      // Create typed data for EIP-712 signing
      final typedData = _createTypedData(metaTxData, contractAddress);
      
      // Sign the typed data
      final signature = await _walletService.signTypedData(typedData: typedData);
      
      // Send the meta-transaction to the relayer
      final response = await http.post(
        Uri.parse('$_relayerUrl/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from': userAddress,
          'to': contractAddress,
          'nonce': actualNonce,
          'functionSignature': functionSignature,
          'functionParams': functionParams,
          'signature': signature,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Relayer error: ${response.body}');
      }
      
      final responseData = jsonDecode(response.body);
      return responseData['txHash'];
    } catch (e) {
      debugPrint('Error executing meta-transaction: $e');
      throw Exception('Failed to execute meta-transaction: ${e.toString()}');
    }
  }
  
  /// Get the current nonce for a user on a specific contract
  Future<int> _getNonce(String userAddress, String contractAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$_relayerUrl/nonce?address=$userAddress&contract=$contractAddress'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get nonce from relayer');
      }
      
      final responseData = jsonDecode(response.body);
      return responseData['nonce'];
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
  
  /// Create typed data for EIP-712 signing
  Map<String, dynamic> _createTypedData(Map<String, dynamic> metaTxData, String contractAddress) {
    return {
      'types': {
        'EIP712Domain': [
          {'name': 'name', 'type': 'string'},
          {'name': 'version', 'type': 'string'},
          {'name': 'chainId', 'type': 'uint256'},
          {'name': 'verifyingContract', 'type': 'address'},
        ],
        'MetaTransaction': [
          {'name': 'from', 'type': 'address'},
          {'name': 'to', 'type': 'address'},
          {'name': 'nonce', 'type': 'uint256'},
          {'name': 'data', 'type': 'bytes'},
        ],
      },
      'primaryType': 'MetaTransaction',
      'domain': {
        'name': 'DADI Auction',
        'version': '1',
        'chainId': 1, // Replace with actual chain ID
        'verifyingContract': contractAddress,
      },
      'message': metaTxData,
    };
  }
}

/// Helper function to convert bytes to hex string
String bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
