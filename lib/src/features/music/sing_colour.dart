import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// What the voice sings: its colour (from how high the note is) and how
/// bright the lamps should be (louder, and the longer a note is held).
typedef SungColour = ({LightColor color, double brightness, double midi});

/// Sing and colour: low notes are red, higher ones orange, yellow, green,
/// blue and violet; holding a note makes it brighter. Only the pitch and
/// loudness of each moment are worked out, on the phone; nothing is kept.
class PitchWatch {
  PitchWatch({required this.sampleRate});

  final int sampleRate;

  /// Samples looked at for each reading.
  static const window = 1024;

  /// The lowest and highest notes followed (MIDI): E2 to C6.
  static const lowest = 40.0;
  static const highest = 84.0;

  /// Quieter than this (0..1, as the noise light measures it) is silence.
  static const quiet = 0.3;

  /// How long a held note takes to reach full brightness.
  static const holdToFull = Duration(seconds: 2);

  final _samples = <double>[];
  double? _heldMidi;
  var _held = Duration.zero;

  /// Feeds mono 16-bit little-endian PCM; a reading for each full window,
  /// null while it is quiet or no note can be heard.
  SungColour? add(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      _samples.add(data.getInt16(i, Endian.little) / 32768);
    }
    if (_samples.length < window) {
      return null;
    }
    final frame = _samples.sublist(_samples.length - window);
    _samples.clear();
    final step = Duration(microseconds: window * 1000000 ~/ sampleRate);
    var sum = 0.0;
    for (final s in frame) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / window);
    final decibels = 20 * math.log(math.max(rms, 1e-6)) / math.ln10;
    final level = ((decibels + 60) / 50).clamp(0.0, 1.0);
    final frequency = level < quiet ? null : pitchOf(frame, sampleRate);
    if (frequency == null) {
      _heldMidi = null;
      _held = Duration.zero;
      return null;
    }
    final midi = 69 + 12 * math.log(frequency / 440) / math.ln2;
    if (_heldMidi != null && (midi - _heldMidi!).abs() < 1) {
      _held += step;
    } else {
      _heldMidi = midi;
      _held = Duration.zero;
    }
    final hold =
        (_held.inMicroseconds / holdToFull.inMicroseconds).clamp(0.0, 1.0);
    return (
      color: colourOf(midi),
      brightness: (0.35 + 0.35 * level + 0.3 * hold).clamp(0.0, 1.0),
      midi: midi,
    );
  }

  /// The note's colour: red at [lowest] round the rainbow to violet at
  /// [highest].
  static LightColor colourOf(double midi) {
    final t = ((midi - lowest) / (highest - lowest)).clamp(0.0, 1.0);
    return _hue(t * 280);
  }

  static LightColor _hue(double degrees) {
    final h = degrees / 60;
    final x = 1 - (h % 2 - 1).abs();
    final (r, g, b) = switch (h.floor()) {
      0 => (1.0, x, 0.0),
      1 => (x, 1.0, 0.0),
      2 => (0.0, 1.0, x),
      3 => (0.0, x, 1.0),
      4 => (x, 0.0, 1.0),
      _ => (1.0, 0.0, x),
    };
    return LightColor(r, g, b);
  }

  /// The pitch of [frame] in hertz (the YIN method), or null when no clear
  /// note can be heard.
  static double? pitchOf(List<double> frame, int sampleRate) {
    final minTau = math.max(2, sampleRate ~/ 1100);
    final maxTau = math.min(frame.length ~/ 2, sampleRate ~/ 75);
    if (maxTau <= minTau) {
      return null;
    }
    final half = frame.length - maxTau;
    final diff = Float64List(maxTau + 1);
    for (var tau = 1; tau <= maxTau; tau++) {
      var sum = 0.0;
      for (var i = 0; i < half; i++) {
        final d = frame[i] - frame[i + tau];
        sum += d * d;
      }
      diff[tau] = sum;
    }
    // Cumulative mean normalised difference.
    var running = 0.0;
    final cmnd = Float64List(maxTau + 1)..[0] = 1;
    for (var tau = 1; tau <= maxTau; tau++) {
      running += diff[tau];
      cmnd[tau] = running == 0 ? 1 : diff[tau] * tau / running;
    }
    for (var tau = minTau; tau < maxTau; tau++) {
      if (cmnd[tau] < 0.15) {
        while (tau + 1 < maxTau && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        // A parabola through the three points refines the period.
        final a = cmnd[tau - 1], b = cmnd[tau], c = cmnd[tau + 1];
        final denominator = a - 2 * b + c;
        final shift = denominator == 0 ? 0.0 : (a - c) / (2 * denominator);
        return sampleRate / (tau + shift);
      }
    }
    return null;
  }

  static const _prefix = '${LightingEffect.generatedPrefix}sing';

  /// The room while listening: a dim night blue the sung colours shine
  /// over.
  static LightingEffect background(String name) => LightingEffect(
        id: _prefix,
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(minutes: 1),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#141A4A', '#1C2A6B'],
              'brightnessMin': 0.08,
              'brightnessMax': 0.12,
              'speed': 0.01,
            },
          ),
        ],
      );

  static bool isSinging(LightingEffect effect) => effect.id == _prefix;
}
