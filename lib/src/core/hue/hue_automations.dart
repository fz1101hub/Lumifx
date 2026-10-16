import 'hue_models.dart';

/// The two bridge routines LumiFX can make, both run by the bridge itself
/// (no phone needed): lights that brighten before an alarm, and lights
/// that dim at bedtime.
enum HueAutomationKind { wakeUp, goToSleep }

/// The days the bridge accepts in `recurrence_days`, Monday first.
const hueWeekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// A wake-up or go-to-sleep routine on the bridge (a `behavior_instance`
/// of the bridge's own scripts, the same the Hue app makes).
class HueAutomation {
  const HueAutomation({
    required this.id,
    required this.kind,
    required this.name,
    required this.enabled,
    this.hour,
    this.minute,
    this.days = const [],
    this.groupIds = const [],
    this.fade,
  });

  final String id;
  final HueAutomationKind kind;
  final String name;
  final bool enabled;
  final int? hour;
  final int? minute;

  /// Indexes into [hueWeekdays]; empty means once.
  final List<int> days;
  final List<String> groupIds;
  final Duration? fade;

  /// Null for instances of other scripts (timers, coming home...).
  static HueAutomation? fromJson(
    Map<String, Object?> json,
    Map<String, HueAutomationKind> scripts,
  ) {
    final id = json['id'];
    final kind = scripts[json['script_id']];
    if (id is! String || kind == null) {
      return null;
    }
    final configuration = _map(json['configuration']);
    final when = _map(configuration['when']);
    final time = _map(_map(when['time_point'])['time']);
    final days = when['recurrence_days'];
    final fade = _map(configuration[kind == HueAutomationKind.wakeUp
        ? 'fade_in_duration'
        : 'fade_out_duration'])['seconds'];
    final where = configuration['where'];
    return HueAutomation(
      id: id,
      kind: kind,
      name: _map(json['metadata'])['name'] as String? ?? '',
      enabled: json['enabled'] == true,
      hour: (time['hour'] as num?)?.toInt(),
      minute: (time['minute'] as num?)?.toInt(),
      days: [
        if (days is List)
          for (final day in days)
            if (hueWeekdays.indexOf('$day') case final i when i >= 0) i,
      ]..sort(),
      groupIds: [
        if (where is List)
          for (final entry in where)
            if (_map(_map(entry)['group'])['rid'] case final String rid) rid,
      ],
      fade: fade is num ? Duration(seconds: fade.toInt()) : null,
    );
  }
}

/// What a new routine should do.
class HueAutomationDraft {
  const HueAutomationDraft({
    required this.kind,
    required this.name,
    required this.hour,
    required this.minute,
    required this.days,
    required this.groups,
    required this.fade,
    this.sunrise = true,
  });

  final HueAutomationKind kind;
  final String name;
  final int hour;
  final int minute;

  /// Indexes into [hueWeekdays]; empty means once.
  final List<int> days;
  final List<HueGroup> groups;
  final Duration fade;

  /// Wake up with sunrise colours (red, orange, then white) instead of
  /// plain white.
  final bool sunrise;

  Map<String, Object> toConfiguration() {
    final when = <String, Object>{
      if (days.isNotEmpty)
        'recurrence_days': [for (final d in days) hueWeekdays[d]],
      'time_point': {
        'type': 'time',
        'time': {'hour': hour, 'minute': minute},
      },
    };
    final where = [
      for (final group in groups)
        {
          'group': {'rid': group.id, 'rtype': group.kind.name},
        },
    ];
    return switch (kind) {
      HueAutomationKind.wakeUp => {
          'end_brightness': 100.0,
          'fade_in_duration': {'seconds': fade.inSeconds},
          'style': sunrise ? 'sunrise' : 'basic',
          'when': when,
          'where': where,
        },
      HueAutomationKind.goToSleep => {
          'end_state': 'turn_off',
          'fade_out_duration': {'seconds': fade.inSeconds},
          'style': 'basic',
          'when': when,
          'where': where,
        },
    };
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};
