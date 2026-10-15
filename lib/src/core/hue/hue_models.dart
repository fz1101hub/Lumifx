import 'dart:math' as math;

import '../color/light_color.dart';

/// A Hue Bridge found on the local network, before or after pairing.
class HueBridgeInfo {
  const HueBridgeInfo({
    required this.id,
    required this.host,
    this.name,
  });

  /// Bridge id as reported by the bridge, lower case (e.g. `001788fffe6a1b2c`).
  final String id;

  /// IP address or host name.
  final String host;
  final String? name;

  String get displayName =>
      name ?? 'Hue Bridge ${id.length > 6 ? id.substring(id.length - 6) : id}';

  /// Bridge ids are 16 hex digits (the bridge's MAC with fffe inserted).
  static bool isValidId(String id) => RegExp(r'^[0-9a-f]{16}$').hasMatch(id);

  @override
  bool operator ==(Object other) =>
      other is HueBridgeInfo && other.id == id && other.host == host;

  @override
  int get hashCode => Object.hash(id, host);
}

/// What LumiFX needs to talk to a paired bridge.
class HueCredentials {
  const HueCredentials({
    required this.bridge,
    required this.applicationKey,
    this.clientKey,
    this.certificateFingerprint,
  });

  factory HueCredentials.fromJson(Map<String, Object?> json) {
    return HueCredentials(
      bridge: HueBridgeInfo(
        id: json['bridgeId']! as String,
        host: json['host']! as String,
        name: json['name'] as String?,
      ),
      applicationKey: json['applicationKey']! as String,
      clientKey: json['clientKey'] as String?,
      certificateFingerprint: json['certificateFingerprint'] as String?,
    );
  }

  final HueBridgeInfo bridge;

  /// Sent as `hue-application-key` on every v2 request.
  final String applicationKey;

  /// PSK for Hue Entertainment streaming; null if not generated.
  final String? clientKey;

  /// SHA-256 of the bridge TLS certificate, pinned on first contact.
  final String? certificateFingerprint;

  HueCredentials copyWith({
    HueBridgeInfo? bridge,
    String? certificateFingerprint,
  }) {
    return HueCredentials(
      bridge: bridge ?? this.bridge,
      applicationKey: applicationKey,
      clientKey: clientKey,
      certificateFingerprint:
          certificateFingerprint ?? this.certificateFingerprint,
    );
  }

  Map<String, Object?> toJson() => {
        'bridgeId': bridge.id,
        'host': bridge.host,
        'name': bridge.name,
        'applicationKey': applicationKey,
        'clientKey': clientKey,
        'certificateFingerprint': certificateFingerprint,
      };
}

class HueLight {
  const HueLight({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.isOn,
    this.brightness,
    this.color,
    this.supportsColor = false,
    this.supportsColorTemperature = false,
    this.mirek,
    this.mirekMin = 153,
    this.mirekMax = 500,
    this.archetype,
  });

  factory HueLight.fromJson(Map<String, Object?> json) {
    final metadata = _map(json['metadata']);
    final on = _map(json['on']);
    final dimming = json['dimming'] == null ? null : _map(json['dimming']);
    final color = json['color'] == null ? null : _map(json['color']);
    final xy = color == null ? null : _map(color['xy']);
    final x = xy?['x'];
    final y = xy?['y'];
    final temperature = json['color_temperature'] == null
        ? null
        : _map(json['color_temperature']);
    final schema = _map(temperature?['mirek_schema']);
    return HueLight(
      id: json['id']! as String,
      name: metadata['name'] as String? ?? 'Light',
      archetype: metadata['archetype'] as String?,
      deviceId: _map(json['owner'])['rid'] as String?,
      isOn: on['on'] as bool? ?? false,
      brightness: (dimming?['brightness'] as num?)?.toDouble(),
      color: x is num && y is num ? (x: x.toDouble(), y: y.toDouble()) : null,
      supportsColor: color != null,
      supportsColorTemperature: temperature != null,
      // Only meaningful while the light is in color-temperature mode.
      mirek: temperature?['mirek_valid'] == true
          ? (temperature?['mirek'] as num?)?.toInt()
          : null,
      mirekMin: (schema['mirek_minimum'] as num?)?.toInt() ?? 153,
      mirekMax: (schema['mirek_maximum'] as num?)?.toInt() ?? 500,
    );
  }

  final String id;
  final String name;

  /// The owning device; rooms list devices rather than lights.
  final String? deviceId;
  final bool isOn;

  /// 0..100, or null for on/off-only lights.
  final double? brightness;
  final ({double x, double y})? color;
  final bool supportsColor;
  final bool supportsColorTemperature;

  /// Current color temperature in mirek, when the light is showing white.
  final int? mirek;
  final int mirekMin;
  final int mirekMax;
  final String? archetype;

  bool get isDimmable => brightness != null;

  /// The command that puts this light back the way it is now.
  HueLightCommand get restoreCommand {
    const transition = Duration(milliseconds: 400);
    if (!isOn) {
      return const HueLightCommand(on: false, transition: transition);
    }
    return HueLightCommand(
      on: true,
      brightness: brightness,
      mirek: mirek,
      xy: mirek == null && supportsColor ? color : null,
      transition: transition,
    );
  }
}

enum HueGroupKind { room, zone }

/// A room or zone, resolved to the lights it contains.
class HueGroup {
  const HueGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.lightIds,
    this.groupedLightId,
    this.archetype,
  });

  final String id;
  final String name;
  final HueGroupKind kind;
  final List<String> lightIds;

  /// The `grouped_light` service for controlling the whole group at once.
  final String? groupedLightId;
  final String? archetype;
}

/// A scene saved on the bridge (made in the Hue app), belonging to one
/// room or zone.
class HueScene {
  const HueScene({
    required this.id,
    required this.name,
    required this.groupId,
    this.isActive = false,
  });

  factory HueScene.fromJson(Map<String, Object?> json) {
    final metadata = _map(json['metadata']);
    final status = _map(json['status'])['active'];
    return HueScene(
      id: json['id']! as String,
      name: metadata['name'] as String? ?? 'Scene',
      groupId: _map(json['group'])['rid'] as String? ?? '',
      // `static` or `dynamic_palette` while the scene is showing.
      isActive: status is String && status != 'inactive',
    );
  }

  final String id;
  final String name;

  /// The room or zone the scene belongs to.
  final String groupId;

  /// The bridge believes the lights currently show this scene.
  final bool isActive;
}

/// A partial state update for one light (Hue API v2 `PUT light`).
class HueLightCommand {
  const HueLightCommand({
    this.on,
    this.brightness,
    this.xy,
    this.mirek,
    this.transition,
  });

  /// Shows [color] at [brightness] (0..1) as well as [light] can: in color,
  /// as the nearest white for white-ambiance lights, or as brightness only.
  /// Sending an unsupported property makes the bridge reject the whole
  /// command, so properties a light lacks are left out.
  factory HueLightCommand.forLight(
    HueLight light,
    LightColor color,
    double brightness, {
    Duration? transition,
  }) {
    if (brightness < 0.005) {
      return HueLightCommand(on: false, transition: transition);
    }
    return HueLightCommand(
      on: true,
      brightness:
          light.isDimmable ? (brightness * 100).clamp(1.0, 100.0) : null,
      xy: light.supportsColor ? color.toXy() : null,
      mirek: !light.supportsColor && light.supportsColorTemperature
          ? mirekFor(color, light.mirekMin, light.mirekMax)
          : null,
      transition: transition,
    );
  }

  /// Builds a command that shows [color] at [brightness] (0..1).
  factory HueLightCommand.fromColor(
    LightColor color,
    double brightness, {
    Duration? transition,
  }) {
    if (brightness < 0.005) {
      return HueLightCommand(on: false, transition: transition);
    }
    return HueLightCommand(
      on: true,
      brightness: (brightness * 100).clamp(1.0, 100.0),
      xy: color.toXy(),
      transition: transition,
    );
  }

  /// The white closest to [color], via McCamy's correlated color
  /// temperature approximation, clamped to 2000-6500 K and the light's range.
  static int mirekFor(LightColor color, int minimum, int maximum) {
    final xy = color.toXy();
    final n = (xy.x - 0.3320) / (0.1858 - xy.y);
    final kelvin = (449 * math.pow(n, 3) + 3525 * n * n + 6823.3 * n + 5520.33)
        .clamp(2000.0, 6500.0);
    return (1e6 / kelvin).round().clamp(minimum, maximum);
  }

  final bool? on;

  /// 0..100.
  final double? brightness;
  final ({double x, double y})? xy;
  final int? mirek;
  final Duration? transition;

  Map<String, Object> toJson() => {
        if (on != null) 'on': {'on': on!},
        if (brightness != null)
          'dimming': {'brightness': _round(brightness!, 2)},
        if (xy != null)
          'color': {
            'xy': {'x': _round(xy!.x, 4), 'y': _round(xy!.y, 4)},
          },
        if (mirek != null) 'color_temperature': {'mirek': mirek!},
        if (transition != null)
          'dynamics': {'duration': transition!.inMilliseconds},
      };
}

double _round(double value, int digits) =>
    double.parse(value.toStringAsFixed(digits));

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

/// One addressable segment of an entertainment area. A plain bulb is one
/// channel; gradient lights expose several.
class HueEntertainmentChannel {
  const HueEntertainmentChannel({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.lightIds,
  });

  /// Channel id used in streaming messages (0..255).
  final int id;

  /// Position in the area, each axis -1..1: x left→right, y back→front
  /// (front is where the screen or listener faces), z floor→ceiling.
  final double x;
  final double y;
  final double z;

  /// Lights rendering this channel.
  final List<String> lightIds;
}

/// An entertainment area configured in the Hue app, which can be driven by
/// high-frequency streaming.
class HueEntertainmentArea {
  const HueEntertainmentArea({
    required this.id,
    required this.name,
    required this.channels,
    this.configurationType,
    this.isStreaming = false,
    this.locations = const [],
  });

  final String id;
  final String name;
  final List<HueEntertainmentChannel> channels;

  /// Where each member light was placed; what the area editor edits.
  final List<HueServiceLocation> locations;

  /// `screen`, `music`, `3dspace`, ...
  final String? configurationType;

  /// True while some app (possibly not LumiFX) is streaming to it.
  final bool isStreaming;

  /// Channels ordered left to right, then back to front, so that effects
  /// that move across slots move across the room.
  List<HueEntertainmentChannel> get spatialChannels =>
      [...channels]..sort((a, b) {
          final byX = a.x.compareTo(b.x);
          return byX != 0 ? byX : a.y.compareTo(b.y);
        });
}

/// A point in an entertainment area, each axis -1..1 (see
/// [HueEntertainmentChannel] for the axes).
class HuePosition {
  const HuePosition(this.x, this.y, [this.z = 0]);

  factory HuePosition.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    double axis(String key) =>
        ((map[key] as num?)?.toDouble() ?? 0).clamp(-1.0, 1.0);
    return HuePosition(axis('x'), axis('y'), axis('z'));
  }

  final double x;
  final double y;
  final double z;

  HuePosition copyWith({double? x, double? y, double? z}) => HuePosition(
        (x ?? this.x).clamp(-1.0, 1.0),
        (y ?? this.y).clamp(-1.0, 1.0),
        (z ?? this.z).clamp(-1.0, 1.0),
      );

  Map<String, Object> toJson() => {
        'x': double.parse(x.toStringAsFixed(3)),
        'y': double.parse(y.toStringAsFixed(3)),
        'z': double.parse(z.toStringAsFixed(3)),
      };

  @override
  bool operator ==(Object other) =>
      other is HuePosition && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// A light able to take part in entertainment areas (an `entertainment`
/// service on the bridge).
class HueEntertainmentService {
  const HueEntertainmentService({
    required this.id,
    required this.lightIds,
    this.isRenderer = true,
    this.maxStreams = 1,
  });

  final String id;

  /// Lights of the owning device; usually exactly one.
  final List<String> lightIds;

  /// False for devices that can only proxy the stream, not show it.
  final bool isRenderer;

  /// Independently addressable segments (gradient lights have several).
  final int maxStreams;
}

/// One member light of an area and where it is placed.
class HueServiceLocation {
  const HueServiceLocation({required this.serviceId, required this.positions});

  final String serviceId;

  /// One position per stream; gradient lights may have several.
  final List<HuePosition> positions;

  Map<String, Object> toJson() => {
        'service': {'rid': serviceId, 'rtype': 'entertainment'},
        'positions': [for (final p in positions) p.toJson()],
      };
}

/// What it takes to create or update an entertainment area.
class HueEntertainmentAreaDraft {
  const HueEntertainmentAreaDraft({
    required this.name,
    required this.locations,
    this.configurationType = 'music',
  });

  final String name;

  /// `music`, `screen`, `3dspace` or `other`.
  final String configurationType;
  final List<HueServiceLocation> locations;

  Map<String, Object> toJson() => {
        'metadata': {'name': name},
        'configuration_type': configurationType,
        'locations': {
          'service_locations': [for (final l in locations) l.toJson()],
        },
      };
}
