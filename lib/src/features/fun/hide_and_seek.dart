import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// Where hide and seek is: counting, searching, or found.
enum SeekPhase { counting, searching }

/// Hide and seek: while the seeker counts the lamps dim slowly from a warm
/// glow to almost dark, then a flash for "Ready or not, here I come!" and
/// a dim blue room with a searchlight sweeping across it. Tied to the
/// clock on the wall, as the count is said aloud second by second.
abstract final class HideAndSeek {
  static const countChoices = [10, 20, 30];

  /// How long the search lasts at most, then the lights go back.
  static const search = Duration(minutes: 10);

  static const warm = '#FFD9A0';
  static const night = '#1A2A6C';

  static const _prefix = '${LightingEffect.realTimePrefix}hideseek:';

  static LightingEffect effect(String name, int seconds) {
    final count = Duration(seconds: seconds);
    return LightingEffect(
      id: '$_prefix$seconds',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: count + search,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: count,
          type: EffectEventTypes.ramp,
          parameters: const {
            'color': warm,
            'toColor': '#FF9A50',
            'from': 0.8,
            'to': 0.04,
          },
        ),
        EffectEvent(
          at: count,
          duration: search,
          type: EffectEventTypes.ambientPalette,
          parameters: const {
            'palette': <String>[night, '#24357F'],
            'brightnessMin': 0.1,
            'brightnessMax': 0.18,
            'speed': 0.02,
          },
        ),
        EffectEvent(
          at: count,
          duration: const Duration(milliseconds: 900),
          type: EffectEventTypes.magicFlash,
          parameters: const {
            'color': '#FFFFFF',
            'target': 'all',
            'brightness': 1,
          },
        ),
        // A searchlight sweeping the room every few seconds.
        for (var at = count + const Duration(seconds: 3);
            at < count + search;
            at += const Duration(seconds: 7))
          EffectEvent(
            at: at,
            duration: const Duration(milliseconds: 2500),
            type: EffectEventTypes.travel,
            parameters: const {'color': '#FFF4D6', 'brightness': 0.7},
          ),
      ],
    );
  }

  /// The count of a hide and seek effect, or null for any other effect.
  static int? countOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final seconds = int.tryParse(effect.id.substring(_prefix.length));
    return seconds != null && seconds > 0 && seconds <= 120 ? seconds : null;
  }

  /// The celebration when everyone is found.
  static LightingEffect found(String name) => LightingEffect(
        id: '${LightingEffect.generatedPrefix}hideseek-found',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: const Duration(seconds: 8),
        events: [
          const EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 8),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FFD23F', '#3DDC84', '#FF6FB5', '#40C4FF'],
              'brightnessMin': 0.5,
              'brightnessMax': 0.9,
              'speed': 0.3,
            },
          ),
          for (final (i, color)
              in const ['#FFD23F', '#3DDC84', '#FF6FB5'].indexed)
            EffectEvent(
              at: Duration(milliseconds: 300 + 1200 * i),
              duration: const Duration(milliseconds: 1000),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            ),
        ],
      );
}
