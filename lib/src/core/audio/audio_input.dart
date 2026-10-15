import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// A source of mono 16-bit little-endian PCM audio.
abstract interface class AudioInput {
  int get sampleRate;

  /// Asks for microphone access if needed; false if the user refused.
  Future<bool> requestPermission();

  Future<Stream<Uint8List>> start();

  /// True while audio is being captured, false when the platform paused or
  /// stopped it (a call, another app taking the microphone...). Only
  /// meaningful after [start].
  Stream<bool> get capturing;

  Future<void> stop();
}

/// The phone's microphone. Automatic gain and noise suppression are off:
/// they flatten exactly the dynamics the lights react to.
///
/// The audio session is configured so that LumiFX never silences what the
/// user is listening to: no exclusive audio focus on Android, a mixable
/// session on iOS, and no Bluetooth headset routing (which would switch a
/// Bluetooth speaker to the low-quality hands-free profile).
class MicrophoneAudioInput implements AudioInput {
  AudioRecorder? _recorder;
  final _capturing = StreamController<bool>.broadcast();
  StreamSubscription<RecordState>? _states;

  @override
  int get sampleRate => 44100;

  @override
  Stream<bool> get capturing => _capturing.stream;

  @override
  Future<bool> requestPermission() =>
      (_recorder ??= AudioRecorder()).hasPermission();

  @override
  Future<Stream<Uint8List>> start() async {
    final recorder = _recorder ??= AudioRecorder();
    await _states?.cancel();
    _states = recorder.onStateChanged().listen(
          (state) => _capturing.add(state == RecordState.record),
          onError: (Object _) => _capturing.add(false),
        );
    return recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // iOS: pauses on an interruption (call, Siri) and resumes by itself
        // afterwards. Android: no audio focus request at all, so other apps
        // keep playing and nothing ever pauses the capture.
        audioInterruption: Platform.isIOS
            ? AudioInterruptionMode.pauseResume
            : AudioInterruptionMode.none,
        androidConfig: const AndroidRecordConfig(
          manageBluetooth: false,
          audioSource: AndroidAudioSource.unprocessed,
        ),
        iosConfig: const IosRecordConfig(
          categoryOptions: [IosAudioCategoryOption.mixWithOthers],
          allowHapticsAndSystemSoundsDuringRecording: true,
        ),
      ),
    );
  }

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    await _states?.cancel();
    _states = null;
    if (recorder == null) {
      return;
    }
    try {
      await recorder.stop();
    } finally {
      await recorder.dispose();
      if (!_capturing.isClosed) {
        _capturing.add(false);
      }
    }
  }
}
