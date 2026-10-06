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

  String get displayName => name ?? 'Hue Bridge ${id.substring(id.length - 6)}';

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
    this.archetype,
  });

  factory HueLight.fromJson(Map<String, Object?> json) {
    final metadata = _map(json['metadata']);
    final on = _map(json['on']);
    final dimming = json['dimming'] == null ? null : _map(json['dimming']);
    final color = json['color'] == null ? null : _map(json['color']);
    final xy = color == null ? null : _map(color['xy']);
    return HueLight(
      id: json['id']! as String,
      name: metadata['name'] as String? ?? 'Light',
      archetype: metadata['archetype'] as String?,
      deviceId: _map(json['owner'])['rid'] as String?,
      isOn: on['on'] as bool? ?? false,
      brightness: (dimming?['brightness'] as num?)?.toDouble(),
      color: xy == null
          ? null
          : (x: (xy['x']! as num).toDouble(), y: (xy['y']! as num).toDouble()),
      supportsColor: color != null,
      supportsColorTemperature: json['color_temperature'] != null,
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
  final String? archetype;

  bool get isDimmable => brightness != null;
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

/// A partial state update for one light (Hue API v2 `PUT light`).
class HueLightCommand {
  const HueLightCommand({
    this.on,
    this.brightness,
    this.xy,
    this.mirek,
    this.transition,
  });

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

  /// Position in the area, each axis -1..1: x left→right, y front→back,
  /// z floor→ceiling.
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
  });

  final String id;
  final String name;
  final List<HueEntertainmentChannel> channels;

  /// `screen`, `music`, `3dspace`, ...
  final String? configurationType;

  /// True while some app (possibly not LumiFX) is streaming to it.
  final bool isStreaming;

  /// Channels ordered left to right, then front to back, so that effects
  /// that move across slots move across the room.
  List<HueEntertainmentChannel> get spatialChannels =>
      [...channels]..sort((a, b) {
          final byX = a.x.compareTo(b.x);
          return byX != 0 ? byX : a.y.compareTo(b.y);
        });
}
