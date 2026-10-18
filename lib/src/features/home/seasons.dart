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

/// Festivals whose date follows a lunar calendar, shown on the home in
/// their days alongside the season, if any.
enum Festival { diwali, hanukkah, lunarNewYear }

/// Diwali (Lakshmi Puja), the first evening of Hanukkah and Lunar New
/// Year, from published calendars (Hebcal for Hanukkah); later years have
/// no shelf until the table grows.
const _festivalDays = {
  Festival.diwali: [
    (2025, 10, 20), (2026, 11, 8), (2027, 10, 29), (2028, 10, 17), //
    (2029, 11, 5), (2030, 10, 26), (2031, 11, 14), (2032, 11, 2),
    (2033, 10, 22), (2034, 11, 10), (2035, 10, 31),
  ],
  Festival.hanukkah: [
    (2025, 12, 14), (2026, 12, 4), (2027, 12, 24), (2028, 12, 12), //
    (2029, 12, 1), (2030, 12, 20), (2031, 12, 9), (2032, 11, 27),
    (2033, 12, 16), (2034, 12, 6), (2035, 12, 25),
  ],
  Festival.lunarNewYear: [
    (2025, 1, 29), (2026, 2, 17), (2027, 2, 6), (2028, 1, 26), //
    (2029, 2, 13), (2030, 2, 3), (2031, 1, 23), (2032, 2, 11),
    (2033, 1, 31), (2034, 2, 19), (2035, 2, 8),
  ],
};

/// The festival [now] falls in, if any: Diwali from two days before to
/// two days after, Hanukkah from the day before its first evening to its
/// eighth day, and Lunar New Year from three days before to the seventh
/// day. Festivals never overlap one another.
Festival? festivalOf(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (final MapEntry(key: festival, value: days) in _festivalDays.entries) {
    final (before, after) = switch (festival) {
      Festival.diwali => (2, 2),
      Festival.hanukkah => (1, 8),
      Festival.lunarNewYear => (3, 6),
    };
    for (final (year, month, day) in days) {
      if (!today.isBefore(DateTime(year, month, day - before)) &&
          !today.isAfter(DateTime(year, month, day + after))) {
        return festival;
      }
    }
  }
  return null;
}

/// The built-in effects of [festival].
List<LightingEffect> effectsOfFestival(Festival festival) {
  final collection = switch (festival) {
    Festival.diwali => 'Diwali',
    Festival.hanukkah => 'Hanukkah',
    Festival.lunarNewYear => 'Lunar New Year',
  };
  return [
    for (final effect in effectCatalog)
      if (effect.collection == collection) effect,
  ];
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
