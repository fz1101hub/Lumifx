import 'dart:math' as math;
import 'dart:typed_data';

import 'synth.dart';

/// How a melody sounds.
enum Instrument {
  /// A soft music box, for lullabies.
  musicBox,

  /// Bright little bells, for carols.
  bells,
}

/// One note: a MIDI pitch (0 for a rest) held for [beats].
class Note {
  const Note(this.midi, this.beats);

  final int midi;
  final double beats;
}

/// A tune made of [notes] at [bpm] beats a minute.
class Melody {
  const Melody({
    required this.id,
    required this.bpm,
    required this.notes,
    this.instrument = Instrument.musicBox,
  });

  final String id;
  final int bpm;
  final List<Note> notes;
  final Instrument instrument;

  Duration get beat => Duration(microseconds: 60000000 ~/ bpm);

  /// Once through.
  Duration get length => beat * notes.fold<double>(0, (t, n) => t + n.beats);

  /// The notes [times] times through, with when each starts and lasts.
  List<(Duration at, Duration length, int midi)> timeline({int times = 1}) {
    final out = <(Duration, Duration, int)>[];
    var at = Duration.zero;
    for (var pass = 0; pass < times; pass++) {
      for (final note in notes) {
        final length = beat * note.beats;
        if (note.midi > 0) {
          out.add((at, length, note.midi));
        }
        at += length;
      }
    }
    return out;
  }

  /// Lowest and highest pitch, to spread the notes over the lamps.
  (int, int) get range {
    final pitches = [
      for (final n in notes)
        if (n.midi > 0) n.midi
    ];
    return (pitches.reduce(math.min), pitches.reduce(math.max));
  }
}

/// [melody] played [times] times through, as samples at [sampleRate],
/// with a short ring at the end. Made of sine partials: nothing recorded,
/// nothing to license (and the tunes themselves are traditional).
Float32List synthesizeMelody(Melody melody, {int times = 1}) {
  final timeline = melody.timeline(times: times);
  final end = melody.length * times + const Duration(milliseconds: 1500);
  final out = Float32List((end.inMicroseconds * sampleRate) ~/ 1000000);
  final (partials, decay) = switch (melody.instrument) {
    // A music box: a clear tone with a little shimmer, dying away.
    Instrument.musicBox => (const [(1.0, 1.0), (2.0, 0.35), (3.0, 0.12)], 3.0),
    // Bells: inharmonic partials, a longer ring.
    Instrument.bells => (
        const [(1.0, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.15)],
        2.2
      ),
  };
  for (final (at, length, midi) in timeline) {
    final frequency = 440 * math.pow(2, (midi - 69) / 12).toDouble();
    final start = (at.inMicroseconds * sampleRate) ~/ 1000000;
    // Each note rings a little past its length.
    final ring = math.min(
      out.length - start,
      ((length.inMicroseconds / 1e6 + 1.2) * sampleRate).round(),
    );
    for (var i = 0; i < ring; i++) {
      final t = i / sampleRate;
      final attack = math.min(1.0, t / 0.004);
      final envelope = attack * math.exp(-t * decay);
      var sample = 0.0;
      for (final (ratio, level) in partials) {
        sample += level * math.sin(2 * math.pi * frequency * ratio * t);
      }
      out[start + i] += sample * envelope * 0.25;
    }
  }
  var peak = 0.0;
  for (final s in out) {
    peak = math.max(peak, s.abs());
  }
  if (peak > 0) {
    final k = 0.7 / peak;
    for (var i = 0; i < out.length; i++) {
      out[i] *= k;
    }
  }
  return out;
}
