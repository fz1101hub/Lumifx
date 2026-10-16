import 'dart:math' as math;
import 'dart:typed_data';

/// Hears someone blowing on the microphone: a loud rush of noise that
/// lasts. Talking, singing and a clap are too quiet or too short.
class BlowDetector {
  BlowDetector({
    required this.sampleRate,
    this.threshold = 0.3,
    this.hold = const Duration(milliseconds: 350),
  });

  final int sampleRate;

  /// Loudness (RMS, 0..1 of full scale) that counts as blowing.
  final double threshold;

  /// How long it has to last.
  final Duration hold;

  var _loud = Duration.zero;

  /// Feeds mono 16-bit little-endian PCM; true once a blow is heard.
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
    final length = Duration(microseconds: samples * 1000000 ~/ sampleRate);
    _loud = rms >= threshold ? _loud + length : Duration.zero;
    return _loud >= hold;
  }

  void reset() => _loud = Duration.zero;
}
