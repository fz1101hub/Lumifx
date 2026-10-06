import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/core/hue/hue_discovery.dart';
import 'src/features/bridge/bridge_controller.dart';
import 'src/features/bridge/credential_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bridge = BridgeController(store: SecureCredentialStore())..initialize();
  runApp(
    LumiFxApp(
      bridge: bridge,
      discovery: CompositeBridgeDiscovery([
        const MdnsBridgeDiscovery(),
        CloudBridgeDiscovery(),
      ]),
    ),
  );
}
