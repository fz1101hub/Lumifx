import '../effects/effect.dart';
import '../effects/effect_event.dart';
import 'melodies.dart';
import 'melody.dart';
import 'synth.dart';

/// What an effect sounds like: ambiences played in a loop under it, and
/// whether its lightning brings thunder.
class Soundscape {
  const Soundscape(
    this.ambiences, {
    this.thunder = false,
    this.melody,
    this.melodyTimes = 1,
  });

  final List<Ambience> ambiences;
  final bool thunder;

  /// A tune played once, [melodyTimes] times through, in time with the
  /// lights (music box and light shows).
  final Melody? melody;
  final int melodyTimes;

  static const silent = Soundscape([]);

  bool get isSilent => ambiences.isEmpty && !thunder && melody == null;
}

/// The id prefix of the effects that play a melody.
const melodyEffectPrefix = '${LightingEffect.generatedPrefix}melody:';

const _byEffect = <String, Soundscape>{
  'fireplace': Soundscape([Ambience.fire]),
  'ocean': Soundscape([Ambience.waves]),
  'aurora': Soundscape([Ambience.wind]),
  'sunset': Soundscape([Ambience.waves]),
  'thunderstorm': Soundscape([Ambience.rain], thunder: true),
  'sleeping_dragon': Soundscape([Ambience.fire, Ambience.cave]),
  'mischievous_ghost': Soundscape([Ambience.wind]),
  'haunted_manor': Soundscape([Ambience.rain, Ambience.wind], thunder: true),
  'enchanted_fairy': Soundscape([Ambience.forest]),
  'goblin_mine': Soundscape([Ambience.cave]),
  'emerald_trickster': Soundscape([Ambience.forest]),
  'christmas_elves': Soundscape([Ambience.fire]),
  'hidden_treasure': Soundscape([Ambience.cave]),
  'krakens_cove': Soundscape([Ambience.waves], thunder: true),
  'dinosaur_valley': Soundscape([Ambience.forest]),
  'deep_sea_glow': Soundscape([Ambience.underwater]),
  'pumpkin_patch': Soundscape([Ambience.wind]),
  'witches_cauldron': Soundscape([Ambience.bubbling, Ambience.fire]),
  'vampires_castle': Soundscape([Ambience.wind, Ambience.rain], thunder: true),
  'santas_workshop': Soundscape([Ambience.fire]),
  'silent_snowfall': Soundscape([Ambience.wind]),
  'candlelight_carol': Soundscape([Ambience.fire]),
};

/// The sounds of [effect]. Music Sync effects stay silent: the microphone
/// would hear them. Effects not listed get thunder if they have lightning.
Soundscape soundscapeOf(LightingEffect effect) {
  if (effect.usesMicrophone) {
    return Soundscape.silent;
  }
  if (effect.id.startsWith(melodyEffectPrefix)) {
    final [id, times, ...] = [
      ...effect.id.substring(melodyEffectPrefix.length).split(':'),
      '',
      '',
    ];
    final melody = melodyById(id);
    return melody == null
        ? Soundscape.silent
        : Soundscape(const [],
            melody: melody,
            melodyTimes: (int.tryParse(times) ?? 1).clamp(1, 20));
  }
  final known = _byEffect[effect.id];
  if (known != null) {
    return known;
  }
  final lightning =
      effect.events.any((e) => e.type == EffectEventTypes.lightning);
  return lightning ? const Soundscape([], thunder: true) : Soundscape.silent;
}
