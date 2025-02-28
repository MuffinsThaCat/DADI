import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

// Simple script to verify Hardhat node is running correctly
void main() async {
  log('Starting Hardhat verification...');
  
  // Hardhat node details
  const rpcUrl = 'http://localhost:8087';
  
  try {
    // Test 1: Check if node is running
    log('\nTest 1: Checking if node is running...');
    final result1 = await sendJsonRpcRequest(rpcUrl, 'eth_chainId', []);
    
    if (result1 != null) {
      final chainId = result1['result'];
      log('✅ Node is running');
      log('Chain ID: $chainId (decimal: ${int.parse(chainId.substring(2), radix: 16)})');
      
      // Test 2: Check contract existence
      log('\nTest 2: Checking contract existence...');
      const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
      
      final result2 = await sendJsonRpcRequest(rpcUrl, 'eth_getCode', [contractAddress, 'latest']);
      
      if (result2 != null) {
        final code = result2['result'];
        if (code != '0x') {
          log('✅ Contract exists at address: $contractAddress');
          log('Code length: ${(code.length - 2) / 2} bytes');
          
          // Test 3: Call contract function
          log('\nTest 3: Calling contract function...');
          final result3 = await sendJsonRpcRequest(rpcUrl, 'eth_call', [
            {
              'to': contractAddress,
              'data': '0x8da5cb5b' // Function signature for owner()
            },
            'latest'
          ]);
          
          if (result3 != null) {
            final ownerResult = result3['result'];
            final ownerAddress = '0x${ownerResult.substring(26)}';
            log('✅ Successfully called contract function');
            log('Owner address: $ownerAddress');
            
            // Test 4: Get accounts
            log('\nTest 4: Getting accounts...');
            final result4 = await sendJsonRpcRequest(rpcUrl, 'eth_accounts', []);
            
            if (result4 != null) {
              final accounts = result4['result'] as List;
              log('✅ Successfully retrieved accounts');
              log('Available accounts: ${accounts.length}');
              for (var i = 0; i < accounts.length; i++) {
                log('  Account $i: ${accounts[i]}');
              }
              
              log('\nSummary:');
              log('✅ Hardhat node is running correctly at $rpcUrl');
              log('✅ Contract is deployed and accessible at $contractAddress');
              log('✅ Contract owner is $ownerAddress');
              log('✅ ${accounts.length} accounts are available');
            } else {
              log('❌ Failed to get accounts');
            }
          } else {
            log('❌ Failed to call contract function');
          }
        } else {
          log('❌ No contract found at address: $contractAddress');
        }
      } else {
        log('❌ Failed to check contract code');
      }
    } else {
      log('❌ Failed to connect to node');
    }
  } catch (e) {
    log('Error: $e');
  }
}

// Logger function to replace print statements
void log(String message) {
  developer.log(message);
  // Keep print for console output during testing but commented out
  // print(message);
}

Future<Map<String, dynamic>?> sendJsonRpcRequest(String rpcUrl, String method, List<dynamic> params) async {
  try {
    final client = HttpClient();
    
    const jsonRpcVersion = '2.0';
    final request = {
      'jsonrpc': jsonRpcVersion,
      'method': method,
      'params': params,
      'id': 1,
    };
    
    final httpRequest = await client.postUrl(Uri.parse(rpcUrl));
    httpRequest.headers.set('content-type', 'application/json');
    httpRequest.write(jsonEncode(request));
    
    final httpResponse = await httpRequest.close();
    
    if (httpResponse.statusCode == 200) {
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      final response = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (response.containsKey('error')) {
        log('Error response: ${response['error']}');
        return null;
      }
      
      return response;
    } else {
      log('HTTP error: ${httpResponse.statusCode}');
      return null;
    }
  } catch (e) {
    log('Request error: $e');
    return null;
  }
}
