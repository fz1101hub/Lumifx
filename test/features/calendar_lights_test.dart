import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/calendar/calendar_source.dart';
import 'package:lumifx/src/features/house/calendar_lights.dart';

void main() {
  final now = DateTime(2026, 10, 27, 8);

  test('lights come before each timed appointment of the next day', () {
    final times = calendarLightTimes([
      CalendarEvent(title: 'School', start: DateTime(2026, 10, 27, 8, 5)),
      CalendarEvent(title: 'Dentist', start: DateTime(2026, 10, 27, 15, 30)),
      CalendarEvent(
          title: 'Also at 15:30', start: DateTime(2026, 10, 27, 15, 30)),
      CalendarEvent(
          title: 'Holiday', start: DateTime(2026, 10, 27), allDay: true),
      CalendarEvent(title: 'Next week', start: DateTime(2026, 11, 3, 9)),
    ], now, 10);
    expect(times, [DateTime(2026, 10, 27, 15, 20)],
        reason: 'too late for school, one light for two at once');
  });

  test('at most eight lights are kept', () {
    final times = calendarLightTimes([
      for (var h = 9; h < 21; h++)
        CalendarEvent(title: '$h', start: DateTime(2026, 10, 27, h)),
    ], now, 5);
    expect(times, hasLength(CalendarLightsSettings.maxLights));
  });

  test('settings are written and read back; nonsense is refused', () {
    const settings = CalendarLightsSettings(
        groupId: '4', minutesBefore: 15, color: '#3DDC84');
    final back = CalendarLightsSettings.decode(settings.encode())!;
    expect(
        (back.groupId, back.minutesBefore, back.color), ('4', 15, '#3DDC84'));
    expect(CalendarLightsSettings.decode('4|7|#3DDC84'), isNull);
    expect(CalendarLightsSettings.decode('4|10|orange'), isNull);
    expect(CalendarLightsSettings.decode(null), isNull);
  });
}
