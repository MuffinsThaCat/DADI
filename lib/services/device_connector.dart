// Platform-agnostic entry point for device connector
// Uses conditional imports to select the correct implementation

// Re-export the interface for convenience
export 'device_connector_interface.dart';

// Export the platform-specific implementation
export 'device_connector/device_connector.dart';

// Re-export the factory function for creating device connectors
import 'device_connector/device_connector.dart';

// Create a proper device connector instance based on the platform
DeviceConnectorInterface createDeviceConnector({bool useMockMode = false}) {
  return createPlatformDeviceConnector(useMockMode: useMockMode);
}
