import 'dart:async';

import 'light_frame.dart';

/// Where rendered frames go: real Hue lights, a preview, a recording...
abstract interface class LightOutput {
  /// Receives the latest desired state per light id. Called on every player
  /// tick; implementations decide what is actually worth sending.
  void update(Map<String, LightFrame> frames, Duration tick);

  Future<void> close();
}

/// Discards frames; used when previewing effects without a bridge.
class NullLightOutput implements LightOutput {
  const NullLightOutput();

  @override
  void update(Map<String, LightFrame> frames, Duration tick) {}

  @override
  Future<void> close() async {}
}

/// Sends frames through a per-light command function while respecting a
/// command budget, as needed by the Hue REST API (about 10 light commands
/// per second per bridge).
///
/// Each tick, the lights whose desired state differs most from what was last
/// sent (weighted by how long ago that was) get the available budget. Every
/// command uses the time since that light's previous command as its
/// transition, so lights glide between samples instead of stepping.
class RateLimitedLightOutput implements LightOutput {
  RateLimitedLightOutput({
    required this.send,
    this.commandsPerSecond = 10,
    this.burst = 2,
    this.maxInFlight = 4,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<void> Function(
    String lightId,
    LightFrame frame,
    Duration transition,
  ) send;
  final double commandsPerSecond;
  final double burst;
  final int maxInFlight;
  final DateTime Function() _clock;

  final _lastSent = <String, LightFrame>{};
  final _lastSentAt = <String, DateTime>{};
  final _pending = <Future<void>>{};
  double _tokens = 0;
  int _inFlight = 0;
  bool _closed = false;

  /// The most recent error from [send], if any.
  Object? lastError;

  /// Smallest change worth a command.
  static const _threshold = 0.01;

  @override
  void update(Map<String, LightFrame> frames, Duration tick) {
    if (_closed) {
      return;
    }
    _tokens = (_tokens + commandsPerSecond * tick.inMicroseconds / 1e6)
        .clamp(0, burst);
    final now = _clock();

    final candidates = <({String id, double score})>[];
    frames.forEach((id, frame) {
      final previous = _lastSent[id];
      final difference = previous == null ? 1.0 : _difference(previous, frame);
      if (difference < _threshold) {
        return;
      }
      final sentAt = _lastSentAt[id];
      final age =
          sentAt == null ? 10.0 : now.difference(sentAt).inMicroseconds / 1e6;
      candidates.add((id: id, score: difference * (0.5 + age)));
    });
    candidates.sort((a, b) => b.score.compareTo(a.score));

    for (final candidate in candidates) {
      if (_tokens < 1 || _inFlight >= maxInFlight) {
        break;
      }
      _tokens -= 1;
      final frame = frames[candidate.id]!;
      final sentAt = _lastSentAt[candidate.id];
      final transition = sentAt == null
          ? const Duration(milliseconds: 400)
          : _clampTransition(now.difference(sentAt));
      _lastSent[candidate.id] = frame;
      _lastSentAt[candidate.id] = now;
      _inFlight++;
      late final Future<void> sending;
      sending = _send(candidate.id, frame, transition)
          .whenComplete(() => _pending.remove(sending));
      _pending.add(sending);
    }
  }

  Future<void> _send(String id, LightFrame frame, Duration transition) async {
    try {
      await send(id, frame, transition);
      lastError = null;
    } on Object catch (error) {
      lastError = error;
      // Forget what we thought the light showed, so the next tick retries
      // even if the desired frame has not moved.
      _lastSent.remove(id);
    } finally {
      _inFlight--;
    }
  }

  /// Stops sending and waits (briefly) for commands already on their way,
  /// so that whatever is sent next, e.g. a restore, lands after them.
  @override
  Future<void> close() async {
    _closed = true;
    if (_pending.isNotEmpty) {
      await Future.wait(_pending.toList())
          .timeout(const Duration(seconds: 3), onTimeout: () => const []);
    }
  }

  static Duration _clampTransition(Duration value) {
    const min = Duration(milliseconds: 100);
    const max = Duration(seconds: 2);
    return value < min ? min : (value > max ? max : value);
  }

  static double _difference(LightFrame a, LightFrame b) {
    if (a.isOff != b.isOff) {
      return 1;
    }
    if (a.isOff) {
      return 0;
    }
    return (a.brightness - b.brightness).abs() +
        ((a.color.r - b.color.r).abs() +
                (a.color.g - b.color.g).abs() +
                (a.color.b - b.color.b).abs()) /
            3;
  }
}
