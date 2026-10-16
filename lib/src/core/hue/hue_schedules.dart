/// An effect the bridge plays at set times by itself: a Hue scene saved
/// from LumiFX (dynamic, so it keeps moving) recalled on a room or zone,
/// and optionally the lights switched off later. Stored as the bridge's
/// own schedules (API v1, the one place a bridge keeps timed scene
/// recalls), tagged so LumiFX finds its own among the Hue app's.
class HueEffectSchedule {
  const HueEffectSchedule({
    required this.id,
    required this.name,
    required this.groupId,
    required this.sceneId,
    required this.hour,
    required this.minute,
    required this.days,
    required this.enabled,
    this.stopId,
    this.stopHour,
    this.stopMinute,
  });

  /// The bridge's id of the schedule that recalls the scene.
  final String id;

  /// The schedule that switches the lights off, if any.
  final String? stopId;
  final String name;

  /// v1 ids: the group (`3`) and the scene (`AbC12dEf`).
  final String groupId;
  final String sceneId;
  final int hour;
  final int minute;
  final int? stopHour;
  final int? stopMinute;

  /// Indexes 0 (Monday) to 6 (Sunday); empty for once.
  final List<int> days;
  final bool enabled;

  /// What every LumiFX schedule's description starts with.
  static const tag = 'lumifx:';

  /// The bridge's limit on schedule names.
  static const maxName = 32;
}

/// What a new schedule should do.
class HueEffectScheduleDraft {
  const HueEffectScheduleDraft({
    required this.name,
    required this.groupId,
    required this.sceneId,
    required this.hour,
    required this.minute,
    required this.days,
    this.stopHour,
    this.stopMinute,
  });

  final String name;
  final String groupId;
  final String sceneId;
  final int hour;
  final int minute;
  final List<int> days;
  final int? stopHour;
  final int? stopMinute;

  bool get stops => stopHour != null && stopMinute != null;
}

/// The bridge's `localtime` for [hour]:[minute] on [days] (0 = Monday),
/// or, with no days, the next time it comes after [now].
String scheduleLocaltime({
  required int hour,
  required int minute,
  required List<int> days,
  required DateTime now,
}) {
  final time = 'T${_two(hour)}:${_two(minute)}:00';
  if (days.isEmpty) {
    var date = DateTime(now.year, now.month, now.day, hour, minute);
    if (!date.isAfter(now)) {
      date = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
        '${_two(date.day)}$time';
  }
  // Monday is the highest of the seven bits, Sunday the lowest.
  var mask = 0;
  for (final day in days) {
    if (day >= 0 && day < 7) {
      mask |= 1 << (6 - day);
    }
  }
  return 'W${mask.toString().padLeft(3, '0')}/$time';
}

/// Reads back [scheduleLocaltime]: the time and days (empty for a single
/// date), or null for anything else (timers, random times).
({int hour, int minute, List<int> days})? parseLocaltime(String localtime) {
  final weekly =
      RegExp(r'^W(\d{1,3})/T(\d\d):(\d\d):\d\d$').firstMatch(localtime);
  if (weekly != null) {
    final mask = int.parse(weekly[1]!);
    final hour = int.parse(weekly[2]!);
    final minute = int.parse(weekly[3]!);
    if (mask < 1 || mask > 127 || hour > 23 || minute > 59) {
      return null;
    }
    return (
      hour: hour,
      minute: minute,
      days: [
        for (var day = 0; day < 7; day++)
          if (mask & (1 << (6 - day)) != 0) day,
      ],
    );
  }
  final once =
      RegExp(r'^\d{4}-\d\d-\d\dT(\d\d):(\d\d):\d\d$').firstMatch(localtime);
  if (once != null) {
    final hour = int.parse(once[1]!);
    final minute = int.parse(once[2]!);
    if (hour > 23 || minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute, days: const <int>[]);
  }
  return null;
}

/// The days the lights switch off: the same ones, or each moved to the
/// next day when the off time is earlier than the start (past midnight).
List<int> stopDays(List<int> days, {required bool nextDay}) =>
    nextDay ? ([for (final day in days) (day + 1) % 7]..sort()) : [...days];

String _two(int value) => value.toString().padLeft(2, '0');
