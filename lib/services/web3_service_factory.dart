import '../services/settings_service.dart';
import 'web3_service_interface.dart';
import 'web3_service_mobile.dart';

/// Factory class to create the appropriate Web3Service implementation
/// based on the current platform
class Web3ServiceFactory {
  /// Create a Web3Service implementation for the current platform
  static Web3ServiceInterface create({required SettingsService settingsService}) {
    // For now, we'll use the mobile implementation for all platforms
    // This avoids the dart:js dependency issues
    // In a real implementation, you would use platform-specific code
    // to load the appropriate implementation
    return Web3ServiceMobile.withSettings(settingsService: settingsService);
  }
}
