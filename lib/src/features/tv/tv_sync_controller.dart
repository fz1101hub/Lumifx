import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/camera/screen_sampler.dart';
import 'camera_input.dart';

enum TvSyncStatus {
  idle,
  starting,
  watching,
  denied,

  /// No camera, or it could not be opened.
  unavailable,
}

/// Watches the TV through the camera and keeps its latest colours, a
/// little smoothed, for the player to read on every tick.
class TvSyncController extends ChangeNotifier {
  TvSyncController(
    this._input, {
    this.smoothing = 0.5,
    this.stallTimeout = const Duration(milliseconds: 1500),
  });

  final CameraInput _input;

  /// How far each new frame moves the colours (1: no smoothing).
  final double smoothing;

  /// Without frames for this long the colours are dropped, so the lights
  /// fall back to the effect's background instead of freezing.
  final Duration stallTimeout;

  TvSyncStatus _status = TvSyncStatus.idle;
  ScreenColors? _colors;
  Timer? _stallTimer;
  bool _disposed = false;

  /// Bumped by every stop, so a start still in progress knows it was
  /// cancelled; operations are chained so they never overlap.
  int _generation = 0;
  Future<void>? _pending;

  TvSyncStatus get status => _status;
  bool get isWatching => _status == TvSyncStatus.watching;

  /// The latest colours of the TV; null until the first frame, after a
  /// stall and when not watching.
  ScreenColors? get colors => isWatching ? _colors : null;

  /// The live camera picture, to aim at the TV.
  Widget? buildPreview() => isWatching ? _input.buildPreview() : null;

  Future<void> start() => _enqueue(_start);

  Future<void> stop() => _enqueue(_stop);

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _pending;
    late final Future<void> current;
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
    if (_status == TvSyncStatus.watching) {
      return;
    }
    final generation = ++_generation;
    _setStatus(TvSyncStatus.starting);
    CameraStartResult result;
    try {
      result = await _input.start((colors) {
        if (generation != _generation || _disposed) {
          return;
        }
        final previous = _colors;
        _colors =
            previous == null ? colors : previous.towards(colors, smoothing);
        _stallTimer?.cancel();
        _stallTimer = Timer(stallTimeout, () => _colors = null);
      });
    } on Object {
      result = CameraStartResult.unavailable;
    }
    if (generation != _generation || _disposed) {
      // Stopped while the camera was opening.
      if (result == CameraStartResult.started) {
        await _input.stop();
      }
      return;
    }
    _setStatus(switch (result) {
      CameraStartResult.started => TvSyncStatus.watching,
      CameraStartResult.denied => TvSyncStatus.denied,
      CameraStartResult.unavailable => TvSyncStatus.unavailable,
    });
  }

  Future<void> _stop() async {
    _generation++;
    _stallTimer?.cancel();
    _colors = null;
    final wasActive =
        _status == TvSyncStatus.watching || _status == TvSyncStatus.starting;
    if (wasActive) {
      try {
        await _input.stop();
      } on Object {
        // Already closed by the platform.
      }
    }
    _setStatus(TvSyncStatus.idle);
  }

  void _setStatus(TvSyncStatus status) {
    _status = status;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _stallTimer?.cancel();
    if (_status == TvSyncStatus.watching || _status == TvSyncStatus.starting) {
      unawaited(_input.stop().catchError((Object _) {}));
    }
    super.dispose();
  }
}
