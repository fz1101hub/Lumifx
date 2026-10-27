import 'dart:async';
import 'dart:convert';

import '../../core/home_away_platform.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../bridge/bridge_controller.dart';
import '../library/preferences_controller.dart';

/// Leaving and coming home: where home is, what happens.
class HomeAwaySettings {
  const HomeAwaySettings({
    required this.latitude,
    required this.longitude,
    required this.sensorId,
    this.radius = 150,
    this.offOnLeave = true,
    this.hallGroupId,
  });

  final double latitude;
  final double longitude;

  /// Metres around home.
  final int radius;

  /// The last one out switches every light off.
  final bool offOnLeave;

  /// The room (v1 id) that lights up on coming home after dark.
  final String? hallGroupId;

  /// This phone's presence sensor on the bridge.
  final String sensorId;

  static const radiusChoices = [100, 150, 300];

  String encode() => jsonEncode({
        'lat': latitude,
        'lon': longitude,
        'r': radius,
        'off': offOnLeave,
        'hall': hallGroupId,
        'sensor': sensorId,
      });

  static HomeAwaySettings? decode(String? text) {
    if (text == null) {
      return null;
    }
    try {
      final json = jsonDecode(text);
      if (json is! Map) {
        return null;
      }
      final lat = json['lat'], lon = json['lon'], r = json['r'];
      final sensor = json['sensor'], hall = json['hall'];
      if (lat is! num ||
          lon is! num ||
          lat.abs() > 90 ||
          lon.abs() > 180 ||
          r is! int ||
          !radiusChoices.contains(r) ||
          sensor is! String ||
          sensor.isEmpty ||
          (hall != null && hall is! String)) {
        return null;
      }
      return HomeAwaySettings(
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        radius: r,
        offOnLeave: json['off'] != false,
        hallGroupId: hall as String?,
        sensorId: sensor,
      );
    } on FormatException {
      return null;
    }
  }

  HomeAwaySettings copyWith({
    int? radius,
    bool? offOnLeave,
    String? Function()? hallGroupId,
  }) =>
      HomeAwaySettings(
        latitude: latitude,
        longitude: longitude,
        sensorId: sensorId,
        radius: radius ?? this.radius,
        offOnLeave: offOnLeave ?? this.offOnLeave,
        hallGroupId: hallGroupId == null ? this.hallGroupId : hallGroupId(),
      );
}

/// What the phone's own code needs to tell the bridge with the app
/// closed: the bridge (address, pinned certificate, key) and the
/// settings; null when it should stop watching.
Map<String, Object?>? homeAwayConfig(
  HomeAwaySettings? settings,
  HueCredentials? credentials,
) {
  final fingerprint = credentials?.certificateFingerprint;
  if (settings == null || credentials == null || fingerprint == null) {
    return null;
  }
  return {
    'host': credentials.bridge.host,
    'bridgeId': credentials.bridge.id,
    'fingerprint': fingerprint,
    'key': credentials.applicationKey,
    'latitude': settings.latitude,
    'longitude': settings.longitude,
    'radius': settings.radius,
    'offOnLeave': settings.offOnLeave,
    'hallGroup': settings.hallGroupId,
    'sensor': settings.sensorId,
  };
}

/// Leaving: this phone is away; if it was the last one home, every light
/// goes off. (The phone's own code, HomeAway.kt and AppDelegate.swift,
/// does the same.)
Future<void> leftHome(HueBridgeClient client, HomeAwaySettings settings) async {
  await client.setPresence(settings.sensorId, false);
  if (settings.offOnLeave && !await client.someoneElseHome(settings.sensorId)) {
    await client.allOff();
  }
}

/// Coming home: this phone is home; after dark the hall lights up.
Future<void> cameHome(HueBridgeClient client, HomeAwaySettings settings) async {
  await client.setPresence(settings.sensorId, true);
  final hall = settings.hallGroupId;
  if (hall != null && await client.isDark()) {
    await client.welcomeHome(hall);
  }
}

/// Keeps the phone's own geofencing in step with the settings and the
/// bridge.
class HomeAwaySync {
  HomeAwaySync({
    required this.platform,
    required this.preferences,
    required this.bridge,
  }) {
    preferences.addListener(_update);
    bridge.addListener(_update);
    _update();
  }

  final HomeAwayPlatform platform;
  final PreferencesController preferences;
  final BridgeController bridge;
  String? _sent;

  void _update() {
    if (!platform.isSupported || !preferences.isLoaded) {
      return;
    }
    final settings = preferences.homeAway;
    // Paired but not connected yet: keep what the phone has.
    if (settings != null && bridge.credentials == null) {
      return;
    }
    final config = homeAwayConfig(settings, bridge.credentials);
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
