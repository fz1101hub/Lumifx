import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// What a door of the advent calendar shows on the lights.
enum AdventMotif { snow, star, bells, candy, aurora, fire }

/// The advent calendar: from 1 to 24 December a door a day, each a short
/// surprise of light. Six motifs in four palettes make 24 different days;
/// the 24th is Christmas Eve.
abstract final class Advent {
  static const days = 24;
  static const length = Duration(seconds: 20);
  static const _prefix = '${LightingEffect.generatedPrefix}advent:';

  static const _palettes = [
    ['#B71C1C', '#1B5E20', '#FFD54F'],
    ['#0D47A1', '#E3F2FD', '#90CAF9'],
    ['#4A148C', '#F8BBD0', '#FFF59D'],
    ['#004D40', '#FFCC80', '#FFFFFF'],
  ];

  static AdventMotif motifOf(int day) =>
      AdventMotif.values[(day - 1) % AdventMotif.values.length];

  /// Doors that may be opened on [today]: up to today's date in December,
  /// all of them until Epiphany, none the rest of the year.
  static int openUpTo(DateTime today) => switch (today.month) {
        12 => today.day.clamp(0, days),
        1 when today.day <= 6 => days,
        _ => 0,
      };

  /// The day of an advent effect, or null for any other effect.
  static int? dayOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final day = int.tryParse(effect.id.substring(_prefix.length));
    return day != null && day >= 1 && day <= days ? day : null;
  }

  /// The surprise behind door [day]; plays once.
  static LightingEffect effect(int day, String name) {
    final palette =
        _palettes[(day - 1) ~/ AdventMotif.values.length % _palettes.length];
    final [first, second, third] = palette;
    EffectEvent ambient(List<String> colors,
            {double low = 0.25, double high = 0.6, double speed = 0.05}) =>
        EffectEvent(
          at: Duration.zero,
          duration: length,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': colors,
            'brightnessMin': low,
            'brightnessMax': high,
            'speed': speed,
          },
        );
    EffectEvent flash(int at, String color, {String target = 'random_light'}) =>
        EffectEvent(
          at: Duration(seconds: at),
          duration: const Duration(milliseconds: 1200),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': color, 'target': target, 'brightness': 0.9},
        );
    final events = switch (day == days ? null : motifOf(day)) {
      AdventMotif.snow => [
          ambient(['#E3F2FD', '#BBDEFB', second], low: 0.3, high: 0.6),
          for (var s = 2; s < 18; s += 4)
            EffectEvent(
              at: Duration(seconds: s),
              duration: const Duration(seconds: 3),
              type: EffectEventTypes.surprise,
              parameters: const {'color': '#FFFFFF', 'count': 3},
            ),
        ],
      AdventMotif.star => [
          ambient(const ['#0B1033', '#1C2A6B'], low: 0.12, high: 0.3),
          for (final s in const [3, 9, 14])
            EffectEvent(
              at: Duration(seconds: s),
              duration: const Duration(seconds: 3),
              type: EffectEventTypes.travel,
              parameters: {
                'color': third,
                'pattern': 'sweep',
                'brightness': 1.0,
              },
            ),
        ],
      AdventMotif.bells => [
          ambient([first, second], low: 0.2, high: 0.45),
          for (var s = 2; s < 18; s += 2) flash(s, '#FFD54F'),
        ],
      AdventMotif.candy => [
          ambient(const ['#D50000', '#FFFFFF'],
              low: 0.35, high: 0.7, speed: 0.1),
          EffectEvent(
            at: const Duration(seconds: 3),
            duration: const Duration(seconds: 12),
            type: EffectEventTypes.travel,
            parameters: const {
              'color': '#FFFFFF',
              'pattern': 'ping_pong',
              'passes': 4,
              'brightness': 1.0,
            },
          ),
        ],
      AdventMotif.aurora => [
          ambient(['#00E5A0', '#7C4DFF', '#00B8D4', third],
              low: 0.25, high: 0.6, speed: 0.08),
        ],
      AdventMotif.fire => [
          EffectEvent(
            at: Duration.zero,
            duration: length,
            type: EffectEventTypes.ambientPalette,
            parameters: const {
              'palette': <String>['#FF7A1A', '#FFB347', '#FF5A0A', '#FFD27F'],
              'brightnessMin': 0.25,
              'brightnessMax': 0.6,
              'speed': 0.07,
              'flicker': 0.9,
            },
          ),
        ],
      // Christmas Eve: every colour of the calendar, and a golden finale.
      null => [
          ambient(const ['#B71C1C', '#1B5E20', '#FFD54F', '#0D47A1'],
              low: 0.35, high: 0.75, speed: 0.08),
          for (final (i, color)
              in const ['#FF3B5C', '#FFD740', '#7CFF6B', '#40C4FF'].indexed)
            EffectEvent(
              at: Duration(seconds: 3 + 3 * i),
              duration: const Duration(seconds: 2),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            ),
          flash(16, '#FFE57F', target: 'all'),
        ],
    };
    return LightingEffect(
      id: '$_prefix$day',
      name: name,
      kind: EffectKind.story,
      isLooping: false,
      loopDuration: length,
      events: events,
    );
  }

  /// The words of door [day].
  static List<(int, String)> narration(int day, AppLocalizations l10n) => [
        (0, l10n.adventDay(day)),
        (
          3,
          day == days
              ? l10n.adventEve
              : switch (motifOf(day)) {
                  AdventMotif.snow => l10n.adventSnow,
                  AdventMotif.star => l10n.adventStar,
                  AdventMotif.bells => l10n.adventBells,
                  AdventMotif.candy => l10n.adventCandy,
                  AdventMotif.aurora => l10n.adventAurora,
                  AdventMotif.fire => l10n.adventFire,
                },
        ),
      ];
}
