import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/fun/advent.dart';
import 'package:lumifx/src/features/fun/countdown.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final library =
      EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));

  group('advent calendar', () {
    test('doors open day by day in December, all until Epiphany', () {
      expect(Advent.openUpTo(DateTime(2026, 11, 30)), 0);
      expect(Advent.openUpTo(DateTime(2026, 12, 1)), 1);
      expect(Advent.openUpTo(DateTime(2026, 12, 13)), 13);
      expect(Advent.openUpTo(DateTime(2026, 12, 31)), 24);
      expect(Advent.openUpTo(DateTime(2027, 1, 6)), 24);
      expect(Advent.openUpTo(DateTime(2027, 1, 7)), 0);
    });

    test('24 surprises, each played once, with its words', () {
      final ids = <String>{};
      for (var day = 1; day <= Advent.days; day++) {
        final effect = Advent.effect(day, 'Day $day');
        expect(ids.add(effect.id), isTrue);
        expect(effect.isGenerated, isTrue);
        expect(effect.isLooping, isFalse);
        expect(effect.hasRapidFlashes, isFalse);
        expect(Advent.dayOf(effect), day);
        for (final event in effect.events) {
          expect(event.end, lessThanOrEqualTo(Advent.length));
        }
        final renderer = EffectRenderer(effect, slotCount: 3, seed: day);
        for (var s = 0; s < 20; s += 2) {
          for (final frame in renderer.render(Duration(seconds: s))) {
            expect(frame.brightness, inInclusiveRange(0, 1));
          }
        }
        final lines = narrationOf(effect, english, library);
        expect(lines.first.$2, 'Day $day');
        expect(lines, hasLength(2));
      }
      expect(Advent.narration(24, english).last.$2,
          "It's Christmas Eve! Merry Christmas!");
    });

    test('opened doors are remembered for the season only', () async {
      final store = InMemoryKeyValueStore();
      final preferences = PreferencesController(store: store);
      await preferences.openAdventDoor(3, DateTime(2026, 12, 3));
      await preferences.openAdventDoor(5, DateTime(2026, 12, 5));
      expect(preferences.isAdventOpened(3, DateTime(2027, 1, 2)), isTrue,
          reason: 'still the 2026 season');
      expect(preferences.isAdventOpened(3, DateTime(2027, 12, 3)), isFalse);
      final again = PreferencesController(store: store);
      await again.load();
      expect(again.isAdventOpened(5, DateTime(2026, 12, 20)), isTrue);
      // A new season forgets the old doors.
      await again.openAdventDoor(1, DateTime(2027, 12, 1));
      expect(again.isAdventOpened(5, DateTime(2026, 12, 20)), isFalse);
    });
  });

  group('countdowns', () {
    final party = Countdown(
        id: 'c1', name: "  Anna's birthday ", date: DateTime(2026, 11, 2));

    test('sleeps by the calendar, whatever the time of day', () {
      expect(party.name, "Anna's birthday");
      expect(party.sleepsFrom(DateTime(2026, 10, 28, 23, 59)), 5);
      expect(party.sleepsFrom(DateTime(2026, 11, 1, 0, 1)), 1);
      expect(party.sleepsFrom(DateTime(2026, 11, 2, 18)), 0);
      expect(party.sleepsFrom(DateTime(2026, 11, 3)), -1);
      // Across a clock change (late October in Europe).
      expect(
          Countdown(id: 'x', name: 'x', date: DateTime(2026, 10, 26))
              .sleepsFrom(DateTime(2026, 10, 24)),
          2);
    });

    test('words, lights and saving', () async {
      expect(party.sleepsText(5, english), "5 sleeps to Anna's birthday!");
      expect(party.sleepsText(1, english), "1 sleep to Anna's birthday!");
      expect(party.sleepsText(0, english), "Today's the day: Anna's birthday!");

      final five = party.effect(5, party.sleepsText(5, english));
      expect(five.isGenerated, isTrue);
      expect(five.isLooping, isFalse);
      expect(Countdown.sleepsOf(five), 5);
      expect(five.events.where((e) => e.parameters['color'] == '#FFD36B'),
          hasLength(5),
          reason: 'a spark per sleep');
      expect(
          party
              .effect(40, 'x')
              .events
              .where((e) => e.parameters['color'] == '#FFD36B'),
          hasLength(10));
      expect(narrationOf(five, english, library).single.$2,
          "5 sleeps to Anna's birthday!");

      final store = InMemoryKeyValueStore();
      final preferences = PreferencesController(store: store);
      await preferences.saveCountdown(
          Countdown(id: 'c2', name: 'Holidays', date: DateTime(2026, 12, 20)));
      await preferences.saveCountdown(party);
      final again = PreferencesController(store: store);
      await again.load();
      expect(
          again.countdowns.map((c) => c.name), ["Anna's birthday", 'Holidays'],
          reason: 'soonest first');
      expect(again.countdowns.first.date, DateTime(2026, 11, 2));
      await again.deleteCountdown('c1');
      expect(again.countdowns.map((c) => c.id), ['c2']);
      expect(Countdown.fromJson({'id': 'x', 'name': 'x', 'date': '2026-13-01'}),
          isNull);
    });
  });
}
