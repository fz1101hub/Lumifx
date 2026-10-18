import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/features/home/seasons.dart';

void main() {
  test('the fixed seasons start and end on the right days', () {
    expect(seasonOf(DateTime(2026, 9, 30)), isNull);
    expect(seasonOf(DateTime(2026, 10, 1)), Season.halloween);
    expect(seasonOf(DateTime(2026, 11, 2)), Season.halloween);
    expect(seasonOf(DateTime(2026, 11, 3)), isNull);
    expect(seasonOf(DateTime(2026, 11, 20)), Season.christmas);
    expect(seasonOf(DateTime(2026, 12, 27)), Season.christmas);
    expect(seasonOf(DateTime(2026, 12, 28)), Season.newYear);
    expect(seasonOf(DateTime(2027, 1, 6)), Season.newYear);
    expect(seasonOf(DateTime(2027, 1, 7)), isNull);
    expect(seasonOf(DateTime(2026, 2, 7)), Season.valentine);
    expect(seasonOf(DateTime(2026, 2, 14)), Season.valentine);
  });

  test('Easter is found for any year', () {
    expect(easterSunday(2024), DateTime(2024, 3, 31));
    expect(easterSunday(2025), DateTime(2025, 4, 20));
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    expect(easterSunday(2038), DateTime(2038, 4, 25));
  });

  test('Carnival and Easter move with Easter', () {
    // 2026: Shrove Tuesday 17 February, Easter 5 April.
    expect(seasonOf(DateTime(2026, 2, 6)), isNull);
    expect(seasonOf(DateTime(2026, 2, 15)), Season.carnival);
    expect(seasonOf(DateTime(2026, 2, 17)), Season.carnival);
    expect(seasonOf(DateTime(2026, 2, 18)), isNull);
    expect(seasonOf(DateTime(2026, 3, 21)), isNull);
    expect(seasonOf(DateTime(2026, 3, 22)), Season.easter);
    expect(seasonOf(DateTime(2026, 4, 6)), Season.easter);
    expect(seasonOf(DateTime(2026, 4, 7)), isNull);
    // 2027: Shrove Tuesday 9 February; Valentine's week comes first.
    expect(seasonOf(DateTime(2027, 2, 5)), Season.carnival);
    expect(seasonOf(DateTime(2027, 2, 8)), Season.valentine);
  });

  test('each season has stories, its own collection first', () {
    for (final season in Season.values) {
      expect(effectsOfSeason(season), isNotEmpty, reason: '$season');
    }
    final halloween = effectsOfSeason(Season.halloween);
    expect(halloween.first.collection, 'Halloween');
    expect(halloween.map((e) => e.collection), contains('Haunted'));
    expect(effectsOfSeason(Season.newYear).first.id, 'new_year_countdown');
    expect(effectsOfSeason(Season.newYear).map((e) => e.collection),
        contains('Christmas Stories'));
  });

  test('holiday stories never flash', () {
    for (final season in [
      Season.newYear,
      Season.valentine,
      Season.carnival,
      Season.easter
    ]) {
      final own = effectsOfSeason(season).first;
      expect(own.hasRapidFlashes, isFalse, reason: own.id);
    }
  });

  test('festivals follow their own calendars', () {
    // Diwali 2026 is on 8 November.
    expect(festivalOf(DateTime(2026, 11, 5)), isNull);
    expect(festivalOf(DateTime(2026, 11, 6)), Festival.diwali);
    expect(festivalOf(DateTime(2026, 11, 10)), Festival.diwali);
    expect(festivalOf(DateTime(2026, 11, 11)), isNull);
    // Hanukkah 2026: first candle the evening of 4 December, eighth day
    // the 12th.
    expect(festivalOf(DateTime(2026, 12, 2)), isNull);
    expect(festivalOf(DateTime(2026, 12, 3)), Festival.hanukkah);
    expect(festivalOf(DateTime(2026, 12, 12)), Festival.hanukkah);
    expect(festivalOf(DateTime(2026, 12, 13)), isNull);
    // Over New Year's Eve in 2027.
    expect(festivalOf(DateTime(2028, 1, 1)), Festival.hanukkah);
    // Lunar New Year 2026 is on 17 February.
    expect(festivalOf(DateTime(2026, 2, 13)), isNull);
    expect(festivalOf(DateTime(2026, 2, 14)), Festival.lunarNewYear);
    expect(festivalOf(DateTime(2026, 2, 23)), Festival.lunarNewYear);
    expect(festivalOf(DateTime(2026, 2, 24)), isNull);
    // Beyond the table: no shelf rather than a wrong one.
    expect(festivalOf(DateTime(2040, 11, 5)), isNull);
  });

  test('a festival and a season can share the home', () {
    final day = DateTime(2026, 2, 14);
    expect(festivalOf(day), Festival.lunarNewYear);
    expect(seasonOf(day), Season.valentine);
    expect(festivalOf(DateTime(2027, 10, 29)), Festival.diwali);
    expect(seasonOf(DateTime(2027, 10, 29)), Season.halloween);
  });

  test('every festival has its own gentle story', () {
    for (final festival in Festival.values) {
      final stories = effectsOfFestival(festival);
      expect(stories, isNotEmpty, reason: '$festival');
      for (final story in stories) {
        expect(story.kind, EffectKind.story);
        expect(story.hasRapidFlashes, isFalse, reason: story.id);
      }
    }
  });
}
