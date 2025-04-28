// Web-specific implementation
// This file is only compiled when targeting web platforms

import '../device_connector_interface.dart';
import '../device_connector_factory.dart';

// Factory function to create device connector for web
DeviceConnectorInterface createDeviceConnector({bool useMockMode = false}) {
  return DeviceConnectorFactory.create(useMockMode: useMockMode);
}
