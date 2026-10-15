import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_input.dart';

enum MusicSyncStatus {
  idle,
  starting,
  listening,
  denied,

  /// The microphone could not be started, or stopped on its own (another
  /// app took it, a call came in and it did not come back).
  failed,
}

/// Listens to the microphone and keeps the latest [AudioFeatures] for the
/// player to read on every tick.
class MusicSyncController extends ChangeNotifier {
  MusicSyncController(
    this._input, {
    DateTime Function()? clock,
    this.stallTimeout = const Duration(milliseconds: 1500),
  }) : _clock = clock ?? DateTime.now;

  final AudioInput _input;
  final DateTime Function() _clock;

  /// Without audio for this long the levels fall to silence, so lights do
  /// not freeze on the last colour when the stream stalls.
  final Duration stallTimeout;

  StreamSubscription<Uint8List>? _subscription;
  StreamSubscription<bool>? _captureStates;
  Timer? _stallTimer;
  AudioFeatures _features = AudioFeatures.silent;
  DateTime _featuresAt = DateTime.fromMillisecondsSinceEpoch(0);
  MusicSyncStatus _status = MusicSyncStatus.idle;
  int _lastNotifiedBeat = 0;
  bool _disposed = false;

  /// Bumped by every stop, so a start still in progress knows it was
  /// cancelled; pending operations are chained so callers never overlap.
  int _generation = 0;
  Future<void>? _pending;

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

  /// Starts listening. Completes when the microphone is running, or when it
  /// could not be started ([status] says why).
  Future<void> start() => _enqueue(_start);

  Future<void> stop() => _enqueue(_stop);

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _pending;
    late final Future<void> current;
    // With nothing in flight the operation starts right away (in the
    // caller's zone); otherwise it waits for the previous one.
    current = (previous == null
            ? operation()
            : previous
                .catchError((Object _) {})
                .then((_) => _disposed ? Future<void>.value() : operation()))
        .whenComplete(() {
      if (identical(_pending, current)) {
        _pending = null;
      }
    });
    return _pending = current;
  }

  Future<void> _start() async {
    if (_status == MusicSyncStatus.listening) {
      return;
    }
    final generation = ++_generation;
    bool cancelled() => _disposed || generation != _generation;
    _setStatus(MusicSyncStatus.starting);
    try {
      if (!await _input.requestPermission()) {
        if (!cancelled()) {
          _setStatus(MusicSyncStatus.denied);
        }
        return;
      }
      if (cancelled()) {
        return;
      }
      final analyzer = AudioAnalyzer(sampleRate: _input.sampleRate);
      final stream = await _input.start();
      if (cancelled()) {
        await _input.stop();
        return;
      }
      _subscription = stream.listen(
        (chunk) {
          if (generation != _generation) {
            return;
          }
          if (analyzer.addPcm16(chunk)) {
            _features = analyzer.features;
            _featuresAt = _clock();
            _armStallTimer();
            // Repaint meters about once per beat, not on every 10 ms step.
            if (_features.beatCount != _lastNotifiedBeat) {
              _lastNotifiedBeat = _features.beatCount;
              _notify();
            }
          }
        },
        onError: (Object _) => _fail(generation),
        onDone: () => _fail(generation),
      );
      _captureStates = _input.capturing.listen((capturing) {
        if (generation != _generation) {
          return;
        }
        if (!capturing) {
          // Paused by the platform: show silence until it comes back.
          _features = AudioFeatures.silent;
          _featuresAt = _clock();
          _notify();
        }
      });
      _armStallTimer();
      _setStatus(MusicSyncStatus.listening);
    } on Object {
      if (!cancelled()) {
        await _tearDown();
        _setStatus(MusicSyncStatus.failed);
      }
    }
  }

  Future<void> _stop() async {
    _generation++;
    final wasActive = _status == MusicSyncStatus.listening ||
        _status == MusicSyncStatus.starting ||
        _status == MusicSyncStatus.failed;
    await _tearDown();
    _features = AudioFeatures.silent;
    if (wasActive) {
      try {
        await _input.stop();
      } on Object {
        // Already stopped by the platform; nothing to release.
      }
    }
    _setStatus(MusicSyncStatus.idle);
  }

  Future<void> _tearDown() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _captureStates?.cancel();
    _captureStates = null;
  }

  /// The stream ended or errored while we were listening.
  void _fail(int generation) {
    if (generation != _generation || _disposed) {
      return;
    }
    _generation++;
    unawaited(_tearDown());
    _features = AudioFeatures.silent;
    _setStatus(MusicSyncStatus.failed);
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(stallTimeout, () {
      if (_status == MusicSyncStatus.listening) {
        _features = AudioFeatures.silent;
        _featuresAt = _clock();
        _notify();
      }
    });
  }

  void _setStatus(MusicSyncStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final wasActive = _status == MusicSyncStatus.listening ||
        _status == MusicSyncStatus.starting ||
        _status == MusicSyncStatus.failed;
    unawaited(_tearDown());
    if (wasActive) {
      unawaited(_input.stop().catchError((Object _) {}));
    }
    super.dispose();
  }
}
