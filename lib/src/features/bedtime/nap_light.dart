import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// A daytime ok-to-wake: a faint amber glow while a child naps, then the
/// lamps slowly turn green when the rest is over, and stay green a while
/// for a child who wakes up and looks.
abstract final class NapLight {
  /// The rests to choose from, in minutes.
  static const choices = [20, 30, 45, 60, 90, 120];

  /// How long the lamps stay green after the rest.
  static const greenFor = Duration(minutes: 20);

  /// How long the lamps take to turn from amber to green.
  static const turning = Duration(seconds: 20);

  static const amber = '#FF8A3D';
  static const green = '#3DDC84';

  static const _prefix = '${LightingEffect.generatedPrefix}nap:';

  /// [rest] of amber glow, then green; it plays once, then the lamps go
  /// back to how they were.
  static LightingEffect effect(String name, Duration rest) => LightingEffect(
        id: '$_prefix${rest.inMinutes}',
        name: name,
        kind: EffectKind.scene,
        isLooping: false,
        loopDuration: rest + greenFor,
        events: [
          EffectEvent(
            at: Duration.zero,
            duration: rest,
            type: EffectEventTypes.ambientPalette,
            parameters: const {
              'palette': <String>[amber, '#FF7A30'],
              'brightnessMin': 0.08,
              'brightnessMax': 0.12,
              'speed': 0.005,
            },
          ),
          EffectEvent(
            at: rest,
            duration: greenFor,
            type: EffectEventTypes.ambientPalette,
            parameters: const {
              'palette': <String>[green, green],
              'brightnessMin': 0.55,
              'brightnessMax': 0.65,
              'speed': 0.01,
            },
          ),
          EffectEvent(
            at: rest,
            duration: turning,
            type: EffectEventTypes.ramp,
            parameters: const {
              'color': amber,
              'toColor': green,
              'from': 0.1,
              'to': 0.6,
            },
          ),
        ],
      );

  /// How long a nap light's rest lasts, or null for any other effect.
  static Duration? restOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final minutes = int.tryParse(effect.id.substring(_prefix.length));
    return minutes != null && minutes > 0 && minutes <= 240
        ? Duration(minutes: minutes)
        : null;
  }
}
