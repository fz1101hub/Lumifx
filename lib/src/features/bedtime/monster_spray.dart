import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The monster spray: little monsters hide in the room, each puff of the
/// spray chases one away, then a guardian light watches over the night.
class MonsterHunt {
  MonsterHunt({this.count = 5}) : _left = count;

  /// Monsters at the start.
  final int count;
  int _left;

  /// Monsters still hiding.
  int get left => _left;

  bool get isDone => _left == 0;

  /// One monster chased away; how many are left.
  int spray() {
    if (_left > 0) {
      _left--;
    }
    return _left;
  }

  /// The colour of a puff of spray.
  static const sprayColor = '#7FFFD4';

  /// How long the guardian light may stay on, in minutes.
  static const guardianMinutes = [15, 30, 60];

  static const _hidingId = '${LightingEffect.generatedPrefix}monsters';
  static const _guardianId = '${LightingEffect.generatedPrefix}guardian';

  /// A dim purple room where monster eyes glint now and then: playful,
  /// never scary.
  static LightingEffect hiding(String name) => LightingEffect(
        id: _hidingId,
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(seconds: 15),
        events: [
          const EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 15),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#2A1B4A', '#1B2A4A', '#3A2350'],
              'brightnessMin': 0.1,
              'brightnessMax': 0.2,
              'speed': 0.03,
            },
          ),
          for (final at in const [3, 8, 12])
            EffectEvent(
              at: Duration(seconds: at),
              duration: const Duration(milliseconds: 500),
              type: EffectEventTypes.magicFlash,
              parameters: const {
                'color': '#B6FF3B',
                'target': 'random_light',
                'brightness': 0.35,
                'chance': 0.7,
              },
            ),
        ],
      );

  /// A warm, low glow for the night.
  static LightingEffect guardian(String name) => LightingEffect(
        id: _guardianId,
        name: name,
        kind: EffectKind.scene,
        loopDuration: const Duration(minutes: 1),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FFB347', '#FFC870', '#FF9F43'],
              'brightnessMin': 0.15,
              'brightnessMax': 0.22,
              'speed': 0.015,
            },
          ),
        ],
      );

  static bool isHunting(LightingEffect effect) => effect.id == _hidingId;
  static bool isGuardian(LightingEffect effect) => effect.id == _guardianId;
}
