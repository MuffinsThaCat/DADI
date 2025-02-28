import 'dart:developer' as developer;
import 'package:dadi/services/web3_service.dart';

void main() async {
  developer.log('Starting Web3 connection test...');
  
  final web3Service = Web3Service();
  
  try {
    // Log Ethereum provider status
    developer.log('Checking Ethereum provider status...');
    await web3Service.logEthereumProviderStatus();
    
    // Connect to Web3
    developer.log('\nConnecting to Web3...');
    final connected = await web3Service.connect();
    developer.log('Connected: $connected');
    
    if (connected) {
      // Check network status
      developer.log('\nChecking network status...');
      final networkInfo = await web3Service.checkNetworkStatus();
      developer.log('Network info: $networkInfo');
      
      // Check contract status
      developer.log('\nContract status:');
      developer.log('Is contract initialized: ${web3Service.isContractInitialized}');
      
      if (web3Service.isContractInitialized) {
        // Test contract
        developer.log('\nTesting contract...');
        try {
          final contractTestResult = await web3Service.testContract();
          developer.log('Contract test result: $contractTestResult');
        } catch (e) {
          developer.log('Contract test failed: $e', error: e);
        }
        
        // Load active auctions
        developer.log('\nLoading active auctions...');
        try {
          await web3Service.loadActiveAuctions();
          final auctions = web3Service.activeAuctions;
          developer.log('Found ${auctions.length} active auctions:');
          auctions.forEach((deviceId, auction) {
            developer.log('- Device ID: $deviceId');
            auction.forEach((key, value) {
              developer.log('  $key: $value');
            });
            developer.log('');
          });
        } catch (e) {
          developer.log('Error loading auctions: $e', error: e);
        }
      } else {
        developer.log('Attempting to initialize contract...');
        final initialized = await web3Service.initializeContract();
        developer.log('Contract initialization result: $initialized');
      }
    }
    
    developer.log('\nTest completed successfully!');
  } catch (e) {
    developer.log('Error during test: $e', error: e);
  }
}
