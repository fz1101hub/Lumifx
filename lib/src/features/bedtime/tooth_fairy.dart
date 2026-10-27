import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The tooth fairy's magic: a soft pink and violet glow with sparkles
/// drifting across the lamps, gentle enough not to wake anyone.
abstract final class ToothFairy {
  static const lasts = Duration(seconds: 40);
  static const pink = '#FFB3E6';
  static const violet = '#C9A0FF';

  /// When she usually comes, before the child wakes up.
  static const defaultHour = 6;

  static const id = '${LightingEffect.generatedPrefix}tooth-fairy';

  /// The star she leaves, one per visit day.
  static String starKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}:toothfairy';

  static LightingEffect effect(String name) => LightingEffect(
        id: id,
        name: name,
        kind: EffectKind.scene,
        isLooping: false,
        loopDuration: lasts,
        events: [
          const EffectEvent(
            at: Duration.zero,
            duration: lasts,
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>[pink, violet, '#FFE6F7'],
              'brightnessMin': 0.2,
              'brightnessMax': 0.45,
              'speed': 0.04,
            },
          ),
          for (var i = 0; i < 6; i++)
            EffectEvent(
              at: Duration(seconds: 3 + 6 * i),
              duration: const Duration(milliseconds: 2500),
              type: EffectEventTypes.travel,
              parameters: {
                'color': i.isEven ? '#FFFFFF' : pink,
                'brightness': 0.7,
              },
            ),
        ],
      );
}
