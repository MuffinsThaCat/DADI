// Top-level device connector file that uses conditional imports
// to include the right implementation based on platform

// Import device_connector_interface.dart
import '../device_connector_interface.dart';

// Re-export the interface
export '../device_connector_interface.dart';

// Platform-specific imports
import 'unsupported.dart'
  if (dart.library.html) 'web.dart'
  if (dart.library.io) 'mobile.dart';

// Factory function to create the right implementation
DeviceConnectorInterface createPlatformDeviceConnector({bool useMockMode = false}) {
  return createDeviceConnector(useMockMode: useMockMode);
}
