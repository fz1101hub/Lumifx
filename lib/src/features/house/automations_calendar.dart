import '../../core/hue/hue_automations.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_house.dart';
import '../../core/hue/hue_reminders.dart';
import '../../core/hue/hue_schedules.dart';

/// What kind of thing the bridge does by itself.
enum CalendarKind {
  effect,
  okToWake,
  wakeUp,
  goToSleep,
  away,
  reminder,
  nightOff
}

/// One thing the bridge does by itself, at a time on some days.
class CalendarEntry {
  const CalendarEntry({
    required this.kind,
    required this.title,
    required this.places,
    required this.hour,
    required this.minute,
    required this.days,
    required this.enabled,
    required this.setEnabled,
  });

  final CalendarKind kind;
  final String title;

  /// The rooms and zones, by id (v1 or v2).
  final List<String> places;
  final int hour;
  final int minute;

  /// 0 (Monday) to 6; empty for once.
  final List<int> days;
  final bool enabled;

  /// Pauses or resumes it, on every day it runs.
  final Future<void> Function(bool enabled) setEnabled;

  bool get isOnce => days.isEmpty;

  int get minutes => hour * 60 + minute;
}

/// Everything the bridge does by itself, LumiFX's and the Hue app's wake-up
/// and go-to-sleep routines; a part that cannot be read is left out.
Future<List<CalendarEntry>> loadCalendar(HueBridgeClient client) async {
  Future<List<T>> safe<T>(Future<List<T>> load) =>
      load.catchError((Object _) => <T>[]);
  final results = await Future.wait<List<Object>>([
    safe(client.fetchEffectSchedules()),
    safe(client.fetchOkToWake()),
    safe(client.fetchAutomations()),
    safe(client.fetchAwayModes()),
    safe(client.fetchLightReminders()),
    safe(client
        .fetchNightOff()
        .then((off) => <HueNightOff>[if (off != null) off])),
  ]);
  const everyDay = [0, 1, 2, 3, 4, 5, 6];
  return [
    for (final s in results[0].cast<HueEffectSchedule>())
      CalendarEntry(
        kind: CalendarKind.effect,
        title: s.name,
        places: [s.groupId],
        hour: s.hour,
        minute: s.minute,
        days: s.days,
        enabled: s.enabled,
        setEnabled: (on) => client.setEffectScheduleEnabled(s, on),
      ),
    for (final w in results[1].cast<HueOkToWake>())
      CalendarEntry(
        kind: CalendarKind.okToWake,
        title: w.name,
        places: [w.groupId],
        hour: w.wakeHour,
        minute: w.wakeMinute,
        days: w.mornings,
        enabled: w.enabled,
        setEnabled: (on) => client.setOkToWakeEnabled(w, on),
      ),
    for (final a in results[2].cast<HueAutomation>())
      if ((a.hour, a.minute) case (final hour?, final minute?))
        CalendarEntry(
          kind: a.kind == HueAutomationKind.wakeUp
              ? CalendarKind.wakeUp
              : CalendarKind.goToSleep,
          title: a.name,
          places: a.groupIds,
          hour: hour,
          minute: minute,
          days: a.days,
          enabled: a.enabled,
          setEnabled: (on) => client.setAutomationEnabled(a.id, on),
        ),
    for (final m in results[3].cast<HueAwayMode>())
      CalendarEntry(
        kind: CalendarKind.away,
        title: m.name,
        places: m.groupIds,
        hour: m.onHour,
        minute: m.onMinute,
        days: m.days,
        enabled: m.enabled,
        setEnabled: (on) => client.setAwayModeEnabled(m, on),
      ),
    for (final r in results[4].cast<HueLightReminder>())
      CalendarEntry(
        kind: CalendarKind.reminder,
        title: r.name,
        places: [r.groupId],
        hour: r.hour,
        minute: r.minute,
        days: r.days,
        enabled: r.enabled,
        setEnabled: (on) => client.setSchedulesEnabled(r.scheduleIds, on),
      ),
    for (final n in results[5].cast<HueNightOff>())
      CalendarEntry(
        kind: CalendarKind.nightOff,
        title: '',
        places: n.groupIds,
        hour: n.hour,
        minute: n.minute,
        days: everyDay,
        enabled: n.enabled,
        setEnabled: (on) => client.setSchedulesEnabled(n.scheduleIds, on),
      ),
  ];
}

/// The entries that run on [day] (0 is Monday), earliest first.
List<CalendarEntry> entriesOn(List<CalendarEntry> entries, int day) => [
      for (final e in entries)
        if (e.days.contains(day)) e,
    ]..sort((a, b) => a.minutes.compareTo(b.minutes));

/// The entries that run once, earliest first.
List<CalendarEntry> onceEntries(List<CalendarEntry> entries) => [
      for (final e in entries)
        if (e.isOnce) e,
    ]..sort((a, b) => a.minutes.compareTo(b.minutes));
