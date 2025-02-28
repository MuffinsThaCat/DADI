import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

void main() async {
  log('Starting blockchain connection test...');
  
  // Test direct RPC connection
  await testRpcConnection();
  
  log('Blockchain connection test completed.');
}

Future<void> testRpcConnection() async {
  const rpcUrl = 'http://localhost:8087';
  log('Testing RPC connection to $rpcUrl');
  
  try {
    // Test 1: Get block number
    final blockNumberResponse = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'jsonrpc': '2.0',
        'method': 'eth_blockNumber',
        'params': [],
        'id': 1,
      }),
    );
    
    if (blockNumberResponse.statusCode == 200) {
      final blockData = json.decode(blockNumberResponse.body);
      log('Block number: ${blockData['result']}');
      log('RPC connection successful!');
    } else {
      log('Failed to get block number. Status code: ${blockNumberResponse.statusCode}');
      log('Response: ${blockNumberResponse.body}');
    }
    
    // Test 2: Check network ID
    final networkResponse = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'jsonrpc': '2.0',
        'method': 'net_version',
        'params': [],
        'id': 2,
      }),
    );
    
    if (networkResponse.statusCode == 200) {
      final networkData = json.decode(networkResponse.body);
      log('Network ID: ${networkData['result']}');
    } else {
      log('Failed to get network ID. Status code: ${networkResponse.statusCode}');
    }
    
    // Test 3: Check contract at the expected address
    const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
    final codeResponse = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'jsonrpc': '2.0',
        'method': 'eth_getCode',
        'params': [contractAddress, 'latest'],
        'id': 3,
      }),
    );
    
    if (codeResponse.statusCode == 200) {
      final codeData = json.decode(codeResponse.body);
      final code = codeData['result'];
      
      if (code != null && code != '0x') {
        log('Contract exists at address $contractAddress');
      } else {
        log('No contract found at address $contractAddress');
      }
    } else {
      log('Failed to check contract. Status code: ${codeResponse.statusCode}');
    }
    
  } catch (e) {
    log('Error testing RPC connection: $e');
  }
}

// Logger function to replace print statements
void log(String message) {
  developer.log(message, name: 'BlockchainTest');
}
