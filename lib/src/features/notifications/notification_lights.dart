import '../../core/color/light_color.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../learn/colour_words.dart';

/// An app whose notifications flash the lights, and in which colour.
class NotificationRule {
  const NotificationRule({
    required this.package,
    required this.label,
    required this.color,
  });

  /// The app's package name, e.g. `com.whatsapp`.
  final String package;

  /// The app's name, as shown on the phone.
  final String label;

  /// The flash's colour, as `#RRGGBB`.
  final String color;

  NotificationRule withColor(String color) =>
      NotificationRule(package: package, label: label, color: color);

  Map<String, Object?> toJson() =>
      {'package': package, 'label': label, 'color': color};

  static NotificationRule? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final package = json['package'];
    final label = json['label'];
    final color = json['color'];
    if (package is! String ||
        package.isEmpty ||
        package.length > 200 ||
        label is! String ||
        color is! String ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
      return null;
    }
    return NotificationRule(
      package: package,
      label: label.length > 80 ? label.substring(0, 80) : label,
      color: color,
    );
  }
}

/// Notification lights as the user set them: which apps flash which
/// colour, in which room, and the quiet hours when nothing flashes.
class NotificationLightsSettings {
  const NotificationLightsSettings({
    this.enabled = false,
    this.rules = const [],
    this.target,
    this.quiet = true,
    this.quietFrom = 22 * 60,
    this.quietTo = 7 * 60,
  });

  final bool enabled;
  final List<NotificationRule> rules;

  /// The room or zone whose lights flash; null for the first room.
  final String? target;

  /// Whether nothing flashes from [quietFrom] to [quietTo] (minutes into
  /// the day; the span may cross midnight).
  final bool quiet;
  final int quietFrom;
  final int quietTo;

  static const maxRules = 20;

  /// Colours to choose from for an app.
  static const colors = [
    '#25D366', '#0A84FF', '#FF3B30', '#FFD60A', '#AF52DE', '#FF9500', //
    '#FF6FB5', '#FFFFFF',
  ];

  /// The name of each of [colors], for screen readers.
  static const colorNames = {
    '#25D366': LearnColour.green,
    '#0A84FF': LearnColour.blue,
    '#FF3B30': LearnColour.red,
    '#FFD60A': LearnColour.yellow,
    '#AF52DE': LearnColour.purple,
    '#FF9500': LearnColour.orange,
    '#FF6FB5': LearnColour.pink,
    '#FFFFFF': LearnColour.white,
  };

  NotificationLightsSettings copyWith({
    bool? enabled,
    List<NotificationRule>? rules,
    String? target,
    bool? quiet,
    int? quietFrom,
    int? quietTo,
  }) =>
      NotificationLightsSettings(
        enabled: enabled ?? this.enabled,
        rules: rules ?? this.rules,
        target: target ?? this.target,
        quiet: quiet ?? this.quiet,
        quietFrom: quietFrom ?? this.quietFrom,
        quietTo: quietTo ?? this.quietTo,
      );

  /// [rules] with [rule] added, or in place of the same app's rule.
  NotificationLightsSettings withRule(NotificationRule rule) {
    final index = rules.indexWhere((r) => r.package == rule.package);
    return copyWith(
      rules: index < 0
          ? [...rules, rule].take(maxRules).toList()
          : [for (final r in rules) r.package == rule.package ? rule : r],
    );
  }

  NotificationLightsSettings withoutRule(String package) => copyWith(rules: [
        for (final r in rules)
          if (r.package != package) r
      ]);

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'rules': [for (final rule in rules) rule.toJson()],
        'target': target,
        'quiet': quiet,
        'quietFrom': quietFrom,
        'quietTo': quietTo,
      };

  static NotificationLightsSettings fromJson(Object? json) {
    if (json is! Map) {
      return const NotificationLightsSettings();
    }
    int minutes(Object? value, int fallback) =>
        value is int && value >= 0 && value < 24 * 60 ? value : fallback;
    final rules = json['rules'];
    final target = json['target'];
    return NotificationLightsSettings(
      enabled: json['enabled'] == true,
      rules: [
        if (rules is List)
          for (final item in rules.take(maxRules))
            if (NotificationRule.fromJson(item) case final rule?) rule,
      ],
      target: target is String ? target : null,
      quiet: json['quiet'] != false,
      quietFrom: minutes(json['quietFrom'], 22 * 60),
      quietTo: minutes(json['quietTo'], 7 * 60),
    );
  }
}

/// The room or zone of [settings], or the first room.
HueGroup? notificationTarget(
        NotificationLightsSettings settings, HueHome home) =>
    home.groups.where((g) => g.id == settings.target).firstOrNull ??
    home.rooms.firstOrNull;

/// What the Android service needs to flash the lights by itself, with the
/// app closed: the bridge, its pinned certificate and key, the lights and
/// each app's colour. Null when there is nothing to flash.
Map<String, Object?>? notificationConfig(
  NotificationLightsSettings settings,
  HueCredentials? credentials,
  HueHome? home,
) {
  final fingerprint = credentials?.certificateFingerprint;
  if (!settings.enabled ||
      settings.rules.isEmpty ||
      credentials == null ||
      fingerprint == null ||
      home == null) {
    return null;
  }
  final group = notificationTarget(settings, home);
  final lights = [
    for (final id in group?.lightIds ?? const <String>[])
      if (home.lights[id] case final light?)
        {'id': light.id, 'color': light.supportsColor},
  ];
  if (lights.isEmpty) {
    return null;
  }
  return {
    'host': credentials.bridge.host,
    'bridgeId': credentials.bridge.id,
    'fingerprint': fingerprint,
    'key': credentials.applicationKey,
    'lights': lights,
    'rules': {
      for (final rule in settings.rules) rule.package: xyOf(rule.color),
    },
    'quiet': settings.quiet
        ? {'from': settings.quietFrom, 'to': settings.quietTo}
        : null,
  };
}

/// The CIE xy of a `#RRGGBB` colour, as the bridge takes it.
Map<String, double> xyOf(String hex) {
  final xy = LightColor.fromHex(hex).toXy();
  double round(double v) => (v * 10000).roundToDouble() / 10000;
  return {'x': round(xy.x), 'y': round(xy.y)};
}
