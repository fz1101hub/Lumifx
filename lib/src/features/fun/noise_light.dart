import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// How loud the room is, as the lamps show it.
enum NoiseZone {
  calm('#2BD94F', 0.5),
  loud('#FFB020', 0.65),
  tooLoud('#FF2D2D', 0.8);

  const NoiseZone(this.color, this.brightness);

  final String color;
  final double brightness;

  static const _prefix = '${LightingEffect.generatedPrefix}noise:';

  /// The whole room in this zone's colour.
  LightingEffect effect(String name) => LightingEffect(
        id: '$_prefix${this.name}',
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
              'brightnessMin': brightness - 0.05,
              'brightnessMax': brightness + 0.05,
              'speed': 0.02,
            },
          ),
        ],
      );

  /// The zone an effect shows, or null for any other effect.
  static NoiseZone? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? values.asNameMap()[effect.id.substring(_prefix.length)]
      : null;
}

/// How much noise is fine: the loudness (0..1, see [NoiseWatch.level])
/// at which the lamps turn amber, and red.
enum NoiseLimit {
  quiet(loud: 0.4, tooLoud: 0.55),
  normal(loud: 0.55, tooLoud: 0.7),
  lively(loud: 0.7, tooLoud: 0.85);

  const NoiseLimit({required this.loud, required this.tooLoud});

  final double loud;
  final double tooLoud;

  NoiseZone zoneOf(double level) => level >= tooLoud
      ? NoiseZone.tooLoud
      : level >= loud
          ? NoiseZone.loud
          : NoiseZone.calm;
}

/// Listens to how loud the room is, never to what is said: only the
/// loudness of each buffer is kept. The zone goes up when the noise has
/// lasted a little and comes down once it has been calmer for a while,
/// so a single clap or a pause for breath does not change the lamps.
class NoiseWatch {
  NoiseWatch({required this.sampleRate, this.limit = NoiseLimit.normal});

  final int sampleRate;
  NoiseLimit limit;

  /// How loud it has been lately: 0 at -60 dBFS (a silent room) or
  /// below, 1 at -10 dBFS (shouting next to the phone).
  double get level => _level;
  var _level = 0.0;

  NoiseZone get zone => _zone;
  var _zone = NoiseZone.calm;

  /// How long louder noise has to last to raise the zone.
  static const rise = Duration(milliseconds: 600);

  /// How long it has to be calmer to lower it.
  static const fall = Duration(seconds: 2);

  NoiseZone? _candidate;
  var _held = Duration.zero;

  /// Feeds mono 16-bit little-endian PCM; true when the zone changed.
  bool add(Uint8List pcm) {
    final samples = pcm.length ~/ 2;
    if (samples == 0) {
      return false;
    }
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples);
    final decibels = 20 * math.log(math.max(rms, 1e-6)) / math.ln10;
    final loudness = ((decibels + 60) / 50).clamp(0.0, 1.0);
    // Quick to rise, slow to settle, like a sound level meter.
    _level += (loudness - _level) * (loudness > _level ? 0.6 : 0.15);

    final target = limit.zoneOf(_level);
    if (target == _zone) {
      _candidate = null;
      _held = Duration.zero;
      return false;
    }
    if (target != _candidate) {
      _candidate = target;
      _held = Duration.zero;
    }
    _held += Duration(microseconds: samples * 1000000 ~/ sampleRate);
    if (_held < (target.index > _zone.index ? rise : fall)) {
      return false;
    }
    _zone = target;
    _candidate = null;
    _held = Duration.zero;
    return true;
  }
}
