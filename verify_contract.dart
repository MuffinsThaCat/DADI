import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Verifying contract on Hardhat node...');
  
  final rpcUrl = 'http://localhost:8087';
  final contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
  
  try {
    // Check if Hardhat node is running
    print('Checking if Hardhat node is running at $rpcUrl...');
    
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'jsonrpc': '2.0',
        'method': 'eth_blockNumber',
        'params': [],
        'id': 1,
      }),
    );
    
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print('Connected to Hardhat node. Current block: ${result['result']}');
      
      // Check if contract exists
      print('Checking if contract exists at address: $contractAddress...');
      
      final codeResponse = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'eth_getCode',
          'params': [contractAddress, 'latest'],
          'id': 2,
        }),
      );
      
      if (codeResponse.statusCode == 200) {
        final codeResult = json.decode(codeResponse.body);
        final code = codeResult['result'] as String;
        
        if (code != '0x' && code.length > 2) {
          print('Contract exists at $contractAddress');
          print('Contract code length: ${code.length}');
          
          // Try to call a contract method (owner)
          final ownerCallData = '0x8da5cb5b'; // Function signature for owner()
          
          final ownerResponse = await http.post(
            Uri.parse(rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'jsonrpc': '2.0',
              'method': 'eth_call',
              'params': [{
                'to': contractAddress,
                'data': ownerCallData,
              }, 'latest'],
              'id': 3,
            }),
          );
          
          if (ownerResponse.statusCode == 200) {
            final ownerResult = json.decode(ownerResponse.body);
            final ownerAddress = ownerResult['result'];
            print('Contract owner: $ownerAddress');
            
            print('Contract verification successful!');
            exit(0);
          } else {
            print('Error calling contract method: ${ownerResponse.statusCode}');
            print('Response: ${ownerResponse.body}');
            exit(1);
          }
        } else {
          print('No contract found at address: $contractAddress');
          exit(1);
        }
      } else {
        print('Error checking contract code: ${codeResponse.statusCode}');
        print('Response: ${codeResponse.body}');
        exit(1);
      }
    } else {
      print('Error connecting to Hardhat node: ${response.statusCode}');
      print('Response: ${response.body}');
      exit(1);
    }
  } catch (e) {
    print('Exception: $e');
    exit(1);
  }
}
