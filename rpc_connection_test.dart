import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

// Simple RPC connection test script
// This script tests direct connection to a JSON-RPC endpoint without any Flutter dependencies

void main() async {
  developer.log('Starting RPC connection test...');
  
  // Hardhat node details
  const rpcUrl = 'http://localhost:8087';
  const jsonRpcVersion = '2.0';
  
  developer.log('Testing connection to: $rpcUrl');
  
  try {
    // Create HTTP client
    final client = HttpClient();
    
    // Prepare JSON-RPC request for eth_chainId
    final request = {
      'jsonrpc': jsonRpcVersion,
      'method': 'eth_chainId',
      'params': [],
      'id': 1,
    };
    
    developer.log('Sending request: ${jsonEncode(request)}');
    
    // Create HTTP request
    final httpRequest = await client.postUrl(Uri.parse(rpcUrl));
    
    // Set headers
    httpRequest.headers.set('content-type', 'application/json');
    
    // Write request body
    httpRequest.write(jsonEncode(request));
    
    // Send request and get response
    final httpResponse = await httpRequest.close();
    
    developer.log('Response status code: ${httpResponse.statusCode}');
    
    // Read response
    final responseBody = await httpResponse.transform(utf8.decoder).join();
    
    developer.log('Response body: $responseBody');
    
    // Parse response
    final response = jsonDecode(responseBody);
    
    if (response.containsKey('result')) {
      final chainId = response['result'];
      developer.log('Successfully connected to RPC endpoint');
      developer.log('Chain ID: $chainId (decimal: ${int.parse(chainId.substring(2), radix: 16)})');
      
      // Test contract call
      await testContractCall(client, rpcUrl, jsonRpcVersion);
    } else if (response.containsKey('error')) {
      developer.log('Error response: ${response['error']}');
    } else {
      developer.log('Unexpected response format: $response');
    }
    
    // Close client
    client.close();
  } catch (e) {
    developer.log('Error connecting to RPC endpoint: $e');
  }
}

Future<void> testContractCall(HttpClient client, String rpcUrl, String jsonRpcVersion) async {
  try {
    // Contract address for DADIAuction
    const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
    
    // Call to get contract owner (assuming there's an 'owner()' function that returns address)
    // Function signature for 'owner()' is '8da5cb5b'
    final request = {
      'jsonrpc': jsonRpcVersion,
      'method': 'eth_call',
      'params': [
        {
          'to': contractAddress,
          'data': '0x8da5cb5b' // Function signature for owner()
        },
        'latest' // Block parameter
      ],
      'id': 2,
    };
    
    developer.log('\nTesting contract call...');
    developer.log('Sending request: ${jsonEncode(request)}');
    
    // Create HTTP request
    final httpRequest = await client.postUrl(Uri.parse(rpcUrl));
    
    // Set headers
    httpRequest.headers.set('content-type', 'application/json');
    
    // Write request body
    httpRequest.write(jsonEncode(request));
    
    // Send request and get response
    final httpResponse = await httpRequest.close();
    
    developer.log('Response status code: ${httpResponse.statusCode}');
    
    // Read response
    final responseBody = await httpResponse.transform(utf8.decoder).join();
    
    developer.log('Response body: $responseBody');
    
    // Parse response
    final response = jsonDecode(responseBody);
    
    if (response.containsKey('result')) {
      final result = response['result'];
      developer.log('Successfully called contract function');
      developer.log('Result: $result');
      
      // If result is an address (it should be for owner()), format it
      if (result.length >= 42) {
        final address = '0x${result.substring(26)}';
        developer.log('Owner address: $address');
      }
    } else if (response.containsKey('error')) {
      developer.log('Error response: ${response['error']}');
    } else {
      developer.log('Unexpected response format: $response');
    }
  } catch (e) {
    developer.log('Error testing contract call: $e');
  }
}
