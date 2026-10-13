import 'package:flutter/widgets.dart';

import 'core/audio/audio_input.dart';
import 'core/hue/hue_discovery.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/library/preferences_controller.dart';

/// App-wide services, provided at the root of the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    required this.audioInput,
    required super.child,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;
  final PreferencesController preferences;

  /// Microphone for Music Sync.
  final AudioInput audioInput;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      bridge != oldWidget.bridge ||
      discovery != oldWidget.discovery ||
      preferences != oldWidget.preferences ||
      audioInput != oldWidget.audioInput;
}
