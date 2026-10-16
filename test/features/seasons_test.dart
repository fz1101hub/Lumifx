import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/home/seasons.dart';

void main() {
  test('the seasons start and end on the right days', () {
    expect(seasonOf(DateTime(2026, 9, 30)), isNull);
    expect(seasonOf(DateTime(2026, 10, 1)), Season.halloween);
    expect(seasonOf(DateTime(2026, 11, 2)), Season.halloween);
    expect(seasonOf(DateTime(2026, 11, 3)), isNull);
    expect(seasonOf(DateTime(2026, 11, 20)), Season.christmas);
    expect(seasonOf(DateTime(2027, 1, 6)), Season.christmas);
    expect(seasonOf(DateTime(2027, 1, 7)), isNull);
  });

  test('each season has stories, its own collection first', () {
    final halloween = effectsOfSeason(Season.halloween);
    expect(halloween.first.collection, 'Halloween');
    expect(halloween.map((e) => e.collection), contains('Haunted'));
    expect(effectsOfSeason(Season.christmas), isNotEmpty);
  });
}
