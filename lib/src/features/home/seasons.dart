import '../../core/effects/effect.dart';
import '../effects/catalog/effect_catalog.dart';

/// Times of year with stories of their own, put first on the home.
enum Season { newYear, valentine, carnival, easter, halloween, christmas }

/// The season [now] falls in, if any: Halloween from 1 October to
/// 2 November, Christmas from 20 November to 27 December, New Year from
/// 28 December to 6 January, Valentine's Day from 7 to 14 February,
/// Carnival in the ten days up to Shrove Tuesday and Easter in the two
/// weeks before Easter Sunday until Easter Monday (both move each year).
Season? seasonOf(DateTime now) {
  final m = now.month;
  final d = now.day;
  if (m == 10 || (m == 11 && d <= 2)) {
    return Season.halloween;
  }
  if ((m == 12 && d >= 28) || (m == 1 && d <= 6)) {
    return Season.newYear;
  }
  if ((m == 11 && d >= 20) || m == 12) {
    return Season.christmas;
  }
  if (m == 2 && d >= 7 && d <= 14) {
    return Season.valentine;
  }
  final today = DateTime(now.year, m, d);
  final easter = easterSunday(now.year);
  // Day arithmetic through the constructor, so summer time never shifts it.
  DateTime daysFromEaster(int days) =>
      DateTime(easter.year, easter.month, easter.day + days);
  final shroveTuesday = daysFromEaster(-47);
  bool within(DateTime from, DateTime to) =>
      !today.isBefore(from) && !today.isAfter(to);
  if (within(
    DateTime(shroveTuesday.year, shroveTuesday.month, shroveTuesday.day - 10),
    shroveTuesday,
  )) {
    return Season.carnival;
  }
  if (within(daysFromEaster(-14), daysFromEaster(1))) {
    return Season.easter;
  }
  return null;
}

/// Easter Sunday of [year] in the Gregorian calendar (the anonymous
/// algorithm, also known as Meeus/Jones/Butcher).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

/// The built-in effects of [season], seasonal collection first.
List<LightingEffect> effectsOfSeason(Season season) {
  final collections = switch (season) {
    Season.newYear => const ['New Year', 'Christmas Stories'],
    Season.valentine => const ['Valentine'],
    Season.carnival => const ['Carnival'],
    Season.easter => const ['Easter'],
    Season.halloween => const ['Halloween', 'Haunted'],
    Season.christmas => const ['Christmas Stories'],
  };
  return [
    for (final collection in collections)
      for (final effect in effectCatalog)
        if (effect.collection == collection) effect,
  ];
}
