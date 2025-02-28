import 'dart:io';
import 'package:flutter/foundation.dart';
import 'wallet_service_interface.dart';
import 'wallet_service_mobile.dart';
import 'wallet_service_web.dart';

/// Factory for creating the appropriate wallet service implementation
class WalletServiceFactory {
  /// Create a wallet service based on the current platform
  static WalletServiceInterface createWalletService({String? rpcUrl}) {
    // Default RPC URL if not provided
    const defaultRpcUrl = 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY';
    final effectiveRpcUrl = rpcUrl ?? defaultRpcUrl;
    
    if (kIsWeb) {
      // Web implementation
      return WalletServiceWeb(rpcUrl: effectiveRpcUrl);
    } else if (Platform.isIOS || Platform.isAndroid) {
      // Mobile implementation
      return WalletServiceMobile(rpcUrl: effectiveRpcUrl);
    } else {
      // Desktop implementation (fallback to mobile for now)
      return WalletServiceMobile(rpcUrl: effectiveRpcUrl);
    }
  }
}
