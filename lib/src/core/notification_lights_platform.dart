import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An app on the phone that may post notifications.
class InstalledApp {
  const InstalledApp({required this.package, required this.label});

  final String package;
  final String label;
}

/// Flashes the lights when chosen apps post a notification. Android only:
/// a notification listener (see NotificationLightsService.kt) that sees
/// which app posted, never what it says, and talks to the bridge itself,
/// so it works with the app closed. iOS lets no app see notifications.
abstract interface class NotificationLightsPlatform {
  bool get isSupported;

  /// Whether the user allowed notification access in the settings.
  Future<bool> hasAccess();

  /// Opens the system page where notification access is allowed.
  Future<void> openAccessSettings();

  /// The apps that can be chosen, by name.
  Future<List<InstalledApp>> apps();

  /// Hands the service what it needs (see `notificationConfig`); null
  /// switches it off.
  Future<void> configure(Map<String, Object?>? config);

  /// Flashes the lights now in [xy], as a notification would.
  Future<bool> test(Map<String, double> xy);
}

class NoNotificationLights implements NotificationLightsPlatform {
  const NoNotificationLights();

  @override
  bool get isSupported => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<List<InstalledApp>> apps() async => const [];

  @override
  Future<void> configure(Map<String, Object?>? config) async {}

  @override
  Future<bool> test(Map<String, double> xy) async => false;
}

class ChannelNotificationLights implements NotificationLightsPlatform {
  ChannelNotificationLights({@visibleForTesting bool? supported})
      : isSupported = supported ?? Platform.isAndroid;

  static const _channel = MethodChannel('com.lumifx/notification_lights');

  @override
  final bool isSupported;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> hasAccess() async => await _invoke<bool>('hasAccess') ?? false;

  @override
  Future<void> openAccessSettings() => _invoke<void>('openAccessSettings');

  @override
  Future<List<InstalledApp>> apps() async {
    final list = await _invoke<List<Object?>>('apps') ?? const [];
    return [
      for (final item in list)
        if (item is Map && item['package'] is String && item['label'] is String)
          InstalledApp(
            package: item['package'] as String,
            label: item['label'] as String,
          ),
    ];
  }

  @override
  Future<void> configure(Map<String, Object?>? config) =>
      _invoke<void>('configure', config == null ? null : jsonEncode(config));

  @override
  Future<bool> test(Map<String, double> xy) async =>
      await _invoke<bool>('test', xy) ?? false;
}
