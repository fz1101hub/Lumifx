import 'dart:typed_data';

import 'package:record/record.dart';

/// A source of mono 16-bit little-endian PCM audio.
abstract interface class AudioInput {
  int get sampleRate;

  /// Asks for microphone access if needed; false if the user refused.
  Future<bool> requestPermission();

  Future<Stream<Uint8List>> start();

  Future<void> stop();
}

/// The phone's microphone. Automatic gain and noise suppression are off:
/// they flatten exactly the dynamics the lights react to.
class MicrophoneAudioInput implements AudioInput {
  AudioRecorder? _recorder;

  @override
  int get sampleRate => 44100;

  @override
  Future<bool> requestPermission() =>
      (_recorder ??= AudioRecorder()).hasPermission();

  @override
  Future<Stream<Uint8List>> start() {
    return (_recorder ??= AudioRecorder()).startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
  }

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.stop();
      await recorder.dispose();
    }
  }
}
