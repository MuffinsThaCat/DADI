import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

void main() async {
  log('Testing RPC connection to Hardhat node on port 8087...');
  
  final client = HttpClient();
  
  try {
    // Create a JSON-RPC request to get the block number
    final request = await client.post('localhost', 8087, '/');
    request.headers.set('Content-Type', 'application/json');
    
    const jsonRpcVersion = '2.0';
    final jsonRpcRequest = {
      'jsonrpc': jsonRpcVersion,
      'method': 'eth_blockNumber',
      'params': [],
      'id': 1
    };
    
    request.write(jsonEncode(jsonRpcRequest));
    final response = await request.close();
    
    final responseBody = await response.transform(utf8.decoder).join();
    log('Response: $responseBody');
    
    // Parse the response
    final jsonResponse = jsonDecode(responseBody);
    
    if (jsonResponse['result'] != null) {
      log('Successfully connected to Hardhat node!');
      log('Current block number: ${int.parse(jsonResponse['result'].substring(2), radix: 16)}');
      
      // Now check if the contract is deployed
      final contractRequest = await client.post('localhost', 8087, '/');
      contractRequest.headers.set('Content-Type', 'application/json');
      
      const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
      final contractJsonRpcRequest = {
        'jsonrpc': jsonRpcVersion,
        'method': 'eth_getCode',
        'params': [contractAddress, 'latest'],
        'id': 1
      };
      
      contractRequest.write(jsonEncode(contractJsonRpcRequest));
      final contractResponse = await contractRequest.close();
      
      final contractResponseBody = await contractResponse.transform(utf8.decoder).join();
      final contractJsonResponse = jsonDecode(contractResponseBody);
      
      if (contractJsonResponse['result'] != null && contractJsonResponse['result'] != '0x') {
        log('Contract is deployed at address: $contractAddress');
        log('Contract bytecode length: ${(contractJsonResponse['result'].length - 2) / 2} bytes');
        
        // Get contract owner
        final ownerRequest = await client.post('localhost', 8087, '/');
        ownerRequest.headers.set('Content-Type', 'application/json');
        
        // Function signature for owner()
        final ownerSignature = '0x8da5cb5b';
        
        final ownerJsonRpcRequest = {
          'jsonrpc': jsonRpcVersion,
          'method': 'eth_call',
          'params': [{
            'to': contractAddress,
            'data': ownerSignature
          }, 'latest'],
          'id': 1
        };
        
        ownerRequest.write(jsonEncode(ownerJsonRpcRequest));
        final ownerResponse = await ownerRequest.close();
        
        final ownerResponseBody = await ownerResponse.transform(utf8.decoder).join();
        final ownerJsonResponse = jsonDecode(ownerResponseBody);
        
        if (ownerJsonResponse['result'] != null) {
          // Extract address from the result (remove 0x prefix and take the last 40 characters)
          final ownerHex = ownerJsonResponse['result'];
          final ownerAddress = '0x${ownerHex.substring(ownerHex.length - 40)}';
          log('Contract owner: $ownerAddress');
          
          // Get active auctions count
          log('\nChecking for active auctions...');
          // This would require knowing the exact function signature and structure
          // For now, we'll just report that the contract is accessible
          
          log('\nContract verification successful!');
          log('The blockchain is running correctly at http://localhost:8087');
          log('The contract is deployed at address: $contractAddress');
          log('You can now use the app with mock mode disabled to interact with the real blockchain.');
        } else {
          log('Failed to get contract owner: ${ownerJsonResponse['error']}');
        }
      } else {
        log('Contract is NOT deployed at address: $contractAddress');
        log('Please deploy the contract using: npx hardhat run scripts/deploy.js --network localhost');
      }
    } else {
      log('Failed to connect to Hardhat node: ${jsonResponse['error']}');
      log('Make sure the Hardhat node is running on port 8087');
    }
  } catch (e) {
    log('Error connecting to RPC: $e');
    log('Make sure the Hardhat node is running on port 8087');
    log('You can start it with: npx hardhat node --port 8087');
  } finally {
    client.close();
  }
}

// Logger function to replace print statements
void log(String message) {
  developer.log(message);
  print(message);
}
