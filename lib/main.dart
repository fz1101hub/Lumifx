import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/core/audio/audio_input.dart';
import 'src/core/hue/hue_discovery.dart';
import 'src/features/bridge/bridge_controller.dart';
import 'src/features/bridge/credential_store.dart';
import 'src/features/library/preferences_controller.dart';
import 'src/features/shortcuts/app_shortcuts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final discovery = CompositeBridgeDiscovery([
    const MdnsBridgeDiscovery(),
    CloudBridgeDiscovery(),
  ]);
  final bridge = BridgeController(
    store: SecureCredentialStore(),
    discovery: discovery,
  )..initialize();
  final preferences = PreferencesController(store: SharedPreferencesStore())
    ..load();
  runApp(
    LumiFxApp(
      bridge: bridge,
      discovery: discovery,
      preferences: preferences,
      audioInput: MicrophoneAudioInput(),
      shortcuts: const QuickActionsShortcuts(),
    ),
  );
}
