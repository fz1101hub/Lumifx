import 'dart:async';

import '../../core/calendar/calendar_source.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../bridge/bridge_controller.dart';
import '../learn/colour_words.dart';
import '../library/preferences_controller.dart';

/// The lights before appointments: which room, how long before, which
/// colour.
class CalendarLightsSettings {
  const CalendarLightsSettings({
    required this.groupId,
    this.minutesBefore = 10,
    this.color = '#FF8C1A',
  });

  /// The v1 id of the room.
  final String groupId;
  final int minutesBefore;

  /// `#RRGGBB`.
  final String color;

  static const minuteChoices = [5, 10, 15, 30];

  /// Orange, blue, purple and green, as the colour words name them.
  static final colorChoices = [
    for (final colour in [
      LearnColour.orange,
      LearnColour.blue,
      LearnColour.purple,
      LearnColour.green,
    ])
      colour.hex,
  ];

  /// How many appointments ahead are kept on the bridge.
  static const maxLights = 8;

  String encode() => '$groupId|$minutesBefore|$color';

  static CalendarLightsSettings? decode(String? text) {
    final [group, minutes, color, ...] = [...?text?.split('|'), '', '', ''];
    final m = int.tryParse(minutes);
    if (group.isEmpty ||
        m == null ||
        !minuteChoices.contains(m) ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
      return null;
    }
    return CalendarLightsSettings(
        groupId: group, minutesBefore: m, color: color);
  }

  CalendarLightsSettings copyWith(
          {String? groupId, int? minutesBefore, String? color}) =>
      CalendarLightsSettings(
        groupId: groupId ?? this.groupId,
        minutesBefore: minutesBefore ?? this.minutesBefore,
        color: color ?? this.color,
      );
}

/// When the lights come for [events]: [minutesBefore] ahead of each
/// appointment with a time (not all-day ones), from [now] to a day later,
/// one per minute, at most [CalendarLightsSettings.maxLights].
List<DateTime> calendarLightTimes(
    List<CalendarEvent> events, DateTime now, int minutesBefore) {
  final times = <DateTime>[];
  for (final event in events) {
    if (event.allDay) {
      continue;
    }
    final at = event.start.subtract(Duration(minutes: minutesBefore));
    final minute = DateTime(at.year, at.month, at.day, at.hour, at.minute);
    if (!minute.isAfter(now) ||
        minute.difference(now) > const Duration(days: 1) ||
        times.contains(minute)) {
      continue;
    }
    times.add(minute);
    if (times.length == CalendarLightsSettings.maxLights) {
      break;
    }
  }
  return times;
}

/// Keeps the bridge's lights before appointments in step with the
/// calendar: when the bridge connects, when the settings change and when
/// the app comes back, at most every few minutes.
class CalendarLightsSync {
  CalendarLightsSync({
    required this.calendar,
    required this.preferences,
    required this.bridge,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    preferences.addListener(_changed);
    bridge.addListener(_changed);
  }

  final CalendarSource calendar;
  final PreferencesController preferences;
  final BridgeController bridge;
  final DateTime Function() _clock;

  static const _again = Duration(minutes: 5);

  String? _settings;
  DateTime? _last;
  var _running = false;

  void _changed() {
    final settings = preferences.calendarLights?.encode() ?? '';
    if (bridge.client == null) {
      return;
    }
    if (settings != _settings) {
      unawaited(sync(force: true));
    }
  }

  /// The app came back: the calendar may have changed meanwhile.
  void resumed() => unawaited(sync());

  /// Sets the lights for the coming day; how many (null when nothing was
  /// done).
  Future<int?> sync({bool force = false}) async {
    final client = bridge.client;
    final now = _clock();
    final last = _last;
    if (client == null ||
        _running ||
        (!force && last != null && now.difference(last) < _again)) {
      return null;
    }
    final settings = preferences.calendarLights;
    final encoded = settings?.encode() ?? '';
    if (settings == null && _settings == null) {
      // Never switched on here: leave the bridge alone.
      _settings = encoded;
      return null;
    }
    _running = true;
    try {
      _settings = encoded;
      _last = now;
      if (settings == null || !await calendar.hasAccess()) {
        await client.clearCalendarLights();
        return 0;
      }
      final events = await calendar.events(
          now, now.add(const Duration(days: 1, hours: 1)));
      return await client.syncCalendarLights(
        times: calendarLightTimes(events, now, settings.minutesBefore),
        groupId: settings.groupId,
        color: settings.color,
        now: now,
      );
    } on Object {
      // The bridge is away: next time.
      _last = null;
      return null;
    } finally {
      _running = false;
    }
  }

  void dispose() {
    preferences.removeListener(_changed);
    bridge.removeListener(_changed);
  }
}
