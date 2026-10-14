import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumifx/src/core/audio/audio_input.dart';

/// 16-bit PCM of a kick drum at [bpm] over a quiet tone.
Uint8List kickTrackPcm({double bpm = 120, double seconds = 4}) {
  const rate = 44100;
  final count = (seconds * rate).round();
  final samples = List<double>.generate(
      count, (i) => 0.02 * math.sin(2 * math.pi * 330 * i / rate));
  for (var start = 0.5; start < seconds; start += 60 / bpm) {
    final first = (start * rate).round();
    for (var i = 0; i < 0.12 * rate && first + i < count; i++) {
      final t = i / rate;
      samples[first + i] +=
          math.exp(-t * 30) * 0.8 * math.sin(2 * math.pi * 55 * t);
    }
  }
  final bytes = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
        i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

class FakeAudioInput implements AudioInput {
  FakeAudioInput({
    this.granted = true,
    Uint8List? pcm,
    this.startDelay = Duration.zero,
    this.failStart = false,
  }) : pcm = pcm ?? kickTrackPcm();

  final bool granted;
  final Uint8List pcm;
  final Duration startDelay;
  final bool failStart;
  bool started = false;
  bool stopped = false;
  int startCount = 0;
  StreamController<Uint8List>? _controller;
  final _capturing = StreamController<bool>.broadcast();

  /// Simulates the platform pausing or stopping the capture.
  void setCapturing(bool value) => _capturing.add(value);

  /// Ends the data stream, like a capture error does on Android.
  Future<void> endStream() async => _close(_controller);

  /// Closing a single-subscription stream nobody listens to never
  /// completes, so it is not awaited.
  static void _close(StreamController<Uint8List>? controller) {
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  Stream<bool> get capturing => _capturing.stream;

  @override
  int get sampleRate => 44100;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<Stream<Uint8List>> start() async {
    if (startDelay > Duration.zero) {
      await Future<void>.delayed(startDelay);
    }
    if (failStart) {
      throw StateError('microphone busy');
    }
    started = true;
    stopped = false;
    startCount++;
    final controller = _controller = StreamController<Uint8List>();
    // Deliver in 4096-byte chunks, like a real microphone buffer.
    for (var i = 0; i < pcm.length; i += 4096) {
      controller
          .add(Uint8List.sublistView(pcm, i, math.min(i + 4096, pcm.length)));
    }
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    final controller = _controller;
    _controller = null;
    _close(controller);
  }
}
