import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_input.dart';

enum MusicSyncStatus { idle, starting, listening, denied, failed }

/// Listens to the microphone and keeps the latest [AudioFeatures] for the
/// player to read on every tick.
class MusicSyncController extends ChangeNotifier {
  MusicSyncController(this._input, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AudioInput _input;
  final DateTime Function() _clock;
  StreamSubscription<Uint8List>? _subscription;
  AudioFeatures _features = AudioFeatures.silent;
  DateTime _featuresAt = DateTime.fromMillisecondsSinceEpoch(0);
  MusicSyncStatus _status = MusicSyncStatus.idle;
  int _lastNotifiedBeat = 0;

  /// Multiplies levels; 1 is neutral.
  double sensitivity = 1.0;

  MusicSyncStatus get status => _status;
  bool get isListening => _status == MusicSyncStatus.listening;

  /// The latest analysis, with beat timing advanced to now and
  /// [sensitivity] applied.
  AudioFeatures get features {
    final age = _clock().difference(_featuresAt).inMicroseconds / 1e6;
    return _features.aged(age < 0 ? 0 : age).scaled(sensitivity);
  }

  Future<void> start() async {
    if (_status == MusicSyncStatus.listening ||
        _status == MusicSyncStatus.starting) {
      return;
    }
    _setStatus(MusicSyncStatus.starting);
    try {
      if (!await _input.requestPermission()) {
        _setStatus(MusicSyncStatus.denied);
        return;
      }
      final analyzer = AudioAnalyzer(sampleRate: _input.sampleRate);
      final stream = await _input.start();
      _subscription = stream.listen(
        (chunk) {
          if (analyzer.addPcm16(chunk)) {
            _features = analyzer.features;
            _featuresAt = _clock();
            // Repaint meters about once per beat or every few chunks, not on
            // every 10 ms analysis step.
            if (_features.beatCount != _lastNotifiedBeat) {
              _lastNotifiedBeat = _features.beatCount;
              notifyListeners();
            }
          }
        },
        onError: (Object _) => _setStatus(MusicSyncStatus.failed),
      );
      _setStatus(MusicSyncStatus.listening);
    } on Object {
      _setStatus(MusicSyncStatus.failed);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _features = AudioFeatures.silent;
    if (_status == MusicSyncStatus.listening ||
        _status == MusicSyncStatus.starting) {
      await _input.stop();
    }
    _setStatus(MusicSyncStatus.idle);
  }

  void _setStatus(MusicSyncStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    if (_status == MusicSyncStatus.listening ||
        _status == MusicSyncStatus.starting) {
      unawaited(_input.stop());
    }
    super.dispose();
  }
}
