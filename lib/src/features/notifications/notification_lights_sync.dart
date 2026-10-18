import 'dart:async';
import 'dart:convert';

import '../../core/notification_lights_platform.dart';
import '../bridge/bridge_controller.dart';
import '../library/preferences_controller.dart';
import 'notification_lights.dart';

/// Keeps the Android service's copy of the notification lights in step
/// with the preferences and the bridge: it flashes the lights by itself,
/// with the app closed.
class NotificationLightsSync {
  NotificationLightsSync({
    required this.platform,
    required this.preferences,
    required this.bridge,
  }) {
    preferences.addListener(_update);
    bridge.addListener(_update);
    _update();
  }

  final NotificationLightsPlatform platform;
  final PreferencesController preferences;
  final BridgeController bridge;

  /// What the service was last given; '' for nothing.
  String? _sent;

  void _update() {
    if (!platform.isSupported || !preferences.isLoaded) {
      return;
    }
    final settings = preferences.notificationLights;
    // Paired but not connected yet (or the bridge is away): the service
    // keeps what it has rather than losing the lights; but switched off,
    // or with no apps left, it must stop at once, bridge or not.
    final off = !settings.enabled || settings.rules.isEmpty;
    if (!off && bridge.credentials != null && bridge.home == null) {
      return;
    }
    final config = off
        ? null
        : notificationConfig(settings, bridge.credentials, bridge.home);
    final encoded = config == null ? '' : jsonEncode(config);
    if (encoded == _sent) {
      return;
    }
    _sent = encoded;
    unawaited(platform.configure(config));
  }

  void dispose() {
    preferences.removeListener(_update);
    bridge.removeListener(_update);
  }
}
