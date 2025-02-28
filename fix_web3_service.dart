import 'dart:developer' as developer;
import 'lib/services/web3_service.dart';

void fixWeb3Service() {
  // Get the Web3Service instance
  final web3Service = Web3Service();
  
  // If it's in mock mode, toggle to real mode
  if (web3Service.isMockMode) {
    developer.log('Web3Service is in mock mode, toggling to real mode...');
    web3Service.toggleMockMode().then((success) {
      if (success) {
        developer.log('Successfully toggled to real blockchain mode');
      } else {
        developer.log('Failed to toggle to real blockchain mode');
      }
    });
  } else {
    developer.log('Web3Service is already in real mode');
    
    // Try to connect if not already connected
    if (!web3Service.isConnected) {
      developer.log('Web3Service is not connected, connecting...');
      web3Service.connect().then((success) {
        if (success) {
          developer.log('Successfully connected to blockchain');
        } else {
          developer.log('Failed to connect to blockchain');
        }
      });
    } else {
      developer.log('Web3Service is already connected');
    }
  }
}
