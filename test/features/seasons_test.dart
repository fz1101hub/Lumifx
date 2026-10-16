import 'package:flutter_test/flutter_test.dart';
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
}
