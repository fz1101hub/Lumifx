import '../../core/effects/effect.dart';
import '../effects/catalog/effect_catalog.dart';

/// Times of year with stories of their own, put first on the home.
enum Season { halloween, christmas }

/// The season [now] falls in, if any: Halloween from 1 October to
/// 2 November, Christmas from 20 November to 6 January.
Season? seasonOf(DateTime now) {
  final m = now.month;
  final d = now.day;
  if (m == 10 || (m == 11 && d <= 2)) {
    return Season.halloween;
  }
  if ((m == 11 && d >= 20) || m == 12 || (m == 1 && d <= 6)) {
    return Season.christmas;
  }
  return null;
}

/// The built-in effects of [season], seasonal collection first.
List<LightingEffect> effectsOfSeason(Season season) {
  final collections = switch (season) {
    Season.halloween => const ['Halloween', 'Haunted'],
    Season.christmas => const ['Christmas Stories'],
  };
  return [
    for (final collection in collections)
      for (final effect in effectCatalog)
        if (effect.collection == collection) effect,
  ];
}
