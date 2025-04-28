// Fallback implementation for unsupported platforms
// This should never be used in practice, but provides a compile-time fallback

import '../device_connector_interface.dart';
import '../device_connector_factory.dart';

// Factory function that defaults to mock implementation
DeviceConnectorInterface createDeviceConnector({bool useMockMode = true}) {
  // Always use mock mode for unsupported platforms
  return DeviceConnectorFactory.create(useMockMode: true);
}
