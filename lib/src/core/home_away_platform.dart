import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Leaving and coming home, watched by the phone's own geofencing (a
/// circle around home), with the app closed: HomeAway.kt on Android
/// (a proximity alert), `HomeAwayBridge` in AppDelegate.swift on iOS
/// (region monitoring). On crossing it, the phone itself tells the
/// bridge (see `homeAwayConfig`).
abstract interface class HomeAwayPlatform {
  bool get isSupported;

  /// Asks for the location, also in the background; false if refused.
  Future<bool> requestAccess();

  /// Where the phone is now, to set home; null if unknown.
  Future<({double latitude, double longitude})?> currentLocation();

  /// Hands over what it needs; null stops watching.
  Future<void> configure(Map<String, Object?>? config);
}

class NoHomeAway implements HomeAwayPlatform {
  const NoHomeAway();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<({double latitude, double longitude})?> currentLocation() async =>
      null;

  @override
  Future<void> configure(Map<String, Object?>? config) async {}
}

class ChannelHomeAway implements HomeAwayPlatform {
  ChannelHomeAway({@visibleForTesting bool? supported})
      : isSupported = supported ?? (Platform.isAndroid || Platform.isIOS);

  static const _channel = MethodChannel('com.lumifx/home_away');

  @override
  final bool isSupported;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Home and away: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> requestAccess() async =>
      await _invoke<bool>('requestAccess') ?? false;

  @override
  Future<({double latitude, double longitude})?> currentLocation() async {
    final found = await _invoke<Map<Object?, Object?>>('currentLocation');
    final latitude = found?['latitude'];
    final longitude = found?['longitude'];
    return latitude is double && longitude is double
        ? (latitude: latitude, longitude: longitude)
        : null;
  }

  @override
  Future<void> configure(Map<String, Object?>? config) =>
      _invoke<void>('configure', config);
}
