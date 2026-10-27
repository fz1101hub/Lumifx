import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/house/automations_calendar.dart';

CalendarEntry _entry(String title, int hour, List<int> days) => CalendarEntry(
      kind: CalendarKind.reminder,
      title: title,
      places: const [],
      hour: hour,
      minute: 0,
      days: days,
      enabled: true,
      setEnabled: (_) async {},
    );

void main() {
  test('each day lists what runs on it, earliest first; once apart', () {
    final entries = [
      _entry('evening', 20, [0, 2]),
      _entry('morning', 7, [0, 1]),
      _entry('party', 18, []),
    ];
    expect([for (final e in entriesOn(entries, 0)) e.title],
        ['morning', 'evening']);
    expect([for (final e in entriesOn(entries, 1)) e.title], ['morning']);
    expect(entriesOn(entries, 6), isEmpty);
    expect([for (final e in onceEntries(entries)) e.title], ['party']);
  });
}
