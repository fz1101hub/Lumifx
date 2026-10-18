import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// A Halloween party: a spooky room, and a scare when someone walks past
/// the motion sensor.
abstract final class HauntedParty {
  static const _id = '${LightingEffect.generatedPrefix}haunted';

  /// The least time between two scares.
  static const rest = Duration(seconds: 15);

  /// Purple, green and midnight blue, low, with a faint green glint now
  /// and then: spooky, never flashing fast.
  static LightingEffect room(String name) => LightingEffect(
        id: _id,
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(seconds: 20),
        events: [
          const EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 20),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#3A1D5C', '#123B1E', '#0B1033', '#5A2A0A'],
              'brightnessMin': 0.08,
              'brightnessMax': 0.22,
              'speed': 0.05,
            },
          ),
          for (final at in const [5, 13])
            EffectEvent(
              at: Duration(seconds: at),
              duration: const Duration(milliseconds: 900),
              type: EffectEventTypes.magicFlash,
              parameters: const {
                'color': '#7CFF6B',
                'target': 'random_light',
                'brightness': 0.35,
                'chance': 0.6,
              },
            ),
        ],
      );

  static bool isParty(LightingEffect effect) => effect.id == _id;
}
