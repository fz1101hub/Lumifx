import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// Hot and cold: a grown-up tells the lights how close the child is to a
/// hidden thing, and the room turns from icy blue to fiery red.
abstract final class HotCold {
  /// From freezing (0) to boiling ([hottest]).
  static const hottest = 10;

  /// Where a game starts: cold.
  static const start = 2;

  static const _prefix = '${LightingEffect.generatedPrefix}hotcold:';
  static const _found = '${_prefix}found';

  static const _stops = [
    '#1F6BFF', '#3FA9F5', '#9FE3FF', '#FFE08A', '#FF9500', '#FF2D1A', //
  ];

  /// The colour of [level].
  static LightColor colorOf(int level) {
    final t = (level.clamp(0, hottest) / hottest) * (_stops.length - 1);
    final i = t.floor().clamp(0, _stops.length - 2);
    return LightColor.lerp(LightColor.fromHex(_stops[i]),
        LightColor.fromHex(_stops[i + 1]), t - i);
  }

  /// The word for [level]: freezing, cold, warm, hot, boiling.
  static String wordOf(AppLocalizations l10n, int level) => switch (level) {
        <= 1 => l10n.hotColdFreezing,
        <= 4 => l10n.hotColdCold,
        <= 6 => l10n.hotColdWarm,
        <= 8 => l10n.hotColdHot,
        _ => l10n.hotColdBoiling,
      };

  /// The room at [level]: brighter and livelier the hotter it is.
  static LightingEffect effect(int level, String name) {
    final color = colorOf(level).toHex();
    final heat = level.clamp(0, hottest) / hottest;
    return LightingEffect(
      id: '$_prefix$level',
      name: name,
      kind: EffectKind.interactive,
      loopDuration: const Duration(minutes: 1),
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: const Duration(minutes: 1),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': [color, color],
            'brightnessMin': 0.3 + 0.4 * heat,
            'brightnessMax': 0.45 + 0.5 * heat,
            'speed': 0.02 + 0.2 * heat,
          },
        ),
      ],
    );
  }

  /// Found it: confetti of light, then the warm room again.
  static LightingEffect found(String name) => LightingEffect(
        id: _found,
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: const Duration(seconds: 8),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 8),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FF2D1A', '#FFD60A', '#34C759', '#0A84FF'],
              'brightnessMin': 0.5,
              'brightnessMax': 0.9,
              'speed': 0.3,
            },
          ),
          EffectEvent(
            at: Duration(milliseconds: 300),
            duration: Duration(seconds: 6),
            type: EffectEventTypes.surprise,
            parameters: {'color': '#FFFFFF', 'count': 10, 'brightness': 1.0},
          ),
        ],
      );

  /// Whether [effect] belongs to the game (a level or the party).
  static bool isHotCold(LightingEffect effect) => effect.id.startsWith(_prefix);
}
