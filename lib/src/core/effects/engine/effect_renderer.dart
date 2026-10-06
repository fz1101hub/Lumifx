import 'dart:math' as math;

import '../../color/light_color.dart';
import '../effect.dart';
import '../effect_event.dart';
import 'light_frame.dart';

/// User-adjustable playback controls, all in 0..1 except [speed].
class EffectControls {
  const EffectControls({
    this.brightness = 1.0,
    this.intensity = 1.0,
    this.speed = 1.0,
  });

  /// Global brightness multiplier.
  final double brightness;

  /// How strong overlays (flashes, travel) and ambient variation are.
  final double intensity;

  /// Time multiplier; applied by the player, not the renderer, so that
  /// changing it mid-playback does not make the timeline jump.
  final double speed;

  EffectControls copyWith({
    double? brightness,
    double? intensity,
    double? speed,
  }) {
    return EffectControls(
      brightness: brightness ?? this.brightness,
      intensity: intensity ?? this.intensity,
      speed: speed ?? this.speed,
    );
  }
}

/// Turns a [LightingEffect] timeline into per-light frames.
///
/// Rendering is a pure function of `(effect, slotCount, seed, elapsed)`:
/// rendering the same instant twice gives the same frames, which keeps the
/// engine testable and lets the player run at any tick rate. Randomness is
/// re-seeded on every pass of the timeline, so long-running stories vary
/// instead of repeating the exact same loop.
///
/// Slots are abstract positions ordered in space (left to right, or around
/// the room); a separate mapping decides which physical light each slot is.
class EffectRenderer {
  EffectRenderer(
    this.effect, {
    required this.slotCount,
    this.seed = 0,
    this.controls = const EffectControls(),
  })  : assert(slotCount > 0, 'An effect needs at least one light'),
        _cycle = effect.cycleLength > _minimumCycle
            ? effect.cycleLength
            : _minimumCycle,
        _ambientIndices = [
          for (var i = 0; i < effect.events.length; i++)
            if (effect.events[i].type == EffectEventTypes.ambientPalette) i,
        ]..sort((a, b) => effect.events[a].at.compareTo(effect.events[b].at));

  static const _minimumCycle = Duration(seconds: 1);

  final LightingEffect effect;
  final int slotCount;
  final int seed;
  EffectControls controls;

  final Duration _cycle;
  final List<int> _ambientIndices;

  Duration get cycleLength => _cycle;

  List<LightFrame> render(Duration elapsed) {
    final total = elapsed.isNegative ? Duration.zero : elapsed;
    final int cycleIndex;
    final Duration local;
    if (effect.isLooping) {
      cycleIndex = total.inMicroseconds ~/ _cycle.inMicroseconds;
      local = Duration(microseconds: total.inMicroseconds % _cycle.inMicroseconds);
    } else {
      // A finished one-shot effect holds its last instant.
      cycleIndex = 0;
      local = total < _cycle ? total : _cycle - const Duration(microseconds: 1);
    }

    final frames = List<LightFrame>.filled(slotCount, LightFrame.off);
    final seconds = total.inMicroseconds / Duration.microsecondsPerSecond;

    final background = _backgroundAt(local);
    if (background != null) {
      _renderAmbient(background, frames, seconds);
    }

    for (var i = 0; i < effect.events.length; i++) {
      final event = effect.events[i];
      if (event.type == EffectEventTypes.ambientPalette ||
          !event.isActiveAt(local)) {
        continue;
      }
      final context = _EventContext(
        event: event,
        local: local - event.at,
        random: math.Random(_mix(seed, cycleIndex, i)),
      );
      switch (event.type) {
        case EffectEventTypes.magicFlash:
          _renderFlash(context, frames);
        case EffectEventTypes.travel:
          _renderTravel(context, frames);
        case EffectEventTypes.surprise:
          _renderSurprise(context, frames);
        case EffectEventTypes.dim:
          _renderDim(context, frames);
        default:
          // Unknown events are skipped so that newer effect definitions
          // still play on older engines.
          break;
      }
    }

    final globalBrightness = controls.brightness.clamp(0.0, 1.0);
    return [
      for (final frame in frames)
        frame.withBrightness(frame.brightness * globalBrightness),
    ];
  }

  /// The ambient event that sets the background at [local]: the latest one
  /// that has started, or, when looping, the last one of the previous pass.
  EffectEvent? _backgroundAt(Duration local) {
    if (_ambientIndices.isEmpty) {
      return null;
    }
    EffectEvent? current;
    for (final index in _ambientIndices) {
      final event = effect.events[index];
      if (event.at <= local) {
        current = event;
      }
    }
    return current ?? effect.events[_ambientIndices.last];
  }

  void _renderAmbient(
    EffectEvent event,
    List<LightFrame> frames,
    double seconds,
  ) {
    final p = event.parameters;
    final palette = _palette(p);
    final minBrightness = _number(p, 'brightnessMin', 0.3);
    final maxBrightness = _number(p, 'brightnessMax', 0.8);
    final speed = _number(p, 'speed', 0.05);
    final flicker = _number(p, 'flicker', 0);
    final intensity = controls.intensity.clamp(0.0, 1.0);

    final middle = (minBrightness + maxBrightness) / 2;
    final amplitude = (maxBrightness - minBrightness) / 2 * intensity;

    for (var slot = 0; slot < slotCount; slot++) {
      final phase = _unit(slot, 1);
      final position = (seconds * speed + phase) * palette.length;
      final index = position.floor() % palette.length;
      final color = LightColor.lerp(
        palette[index],
        palette[(index + 1) % palette.length],
        _smoothstep(position - position.floor()),
      );

      final wave = math.sin(2 * math.pi * (seconds * speed * 1.7 + _unit(slot, 2)));
      var brightness = middle + amplitude * wave;
      if (flicker > 0) {
        brightness += flicker * amplitude * _noise(slot, seconds * 6);
      }
      frames[slot] = LightFrame(color, brightness.clamp(0.0, 1.0));
    }
  }

  void _renderFlash(_EventContext context, List<LightFrame> frames) {
    final p = context.event.parameters;
    final overlay = LightFrame(
      _color(p, 'color', LightColor.white),
      _number(p, 'brightness', 1),
    );
    final alpha = _flashEnvelope(context.progress) * controls.intensity;
    for (final slot in _targets(p, context.random)) {
      frames[slot] = frames[slot].blend(overlay, alpha);
    }
  }

  void _renderTravel(_EventContext context, List<LightFrame> frames) {
    final p = context.event.parameters;
    final overlay = LightFrame(
      _color(p, 'color', LightColor.white),
      _number(p, 'brightness', 0.9),
    );
    final pattern = p['pattern'] as String? ?? 'sweep';
    final edge = _edgeFade(context.progress, 0.1) * controls.intensity;

    if (pattern == 'random_walk') {
      final step = _millis(p, 'stepDuration', 900);
      final stepCount = (context.event.duration.inMicroseconds /
                  step.inMicroseconds)
              .ceil() +
          1;
      final path = _randomWalk(context.random, stepCount);
      final position = context.local.inMicroseconds / step.inMicroseconds;
      final k = position.floor().clamp(0, stepCount - 2);
      final f = _smoothstep(position - k);
      final from = path[k];
      final to = path[k + 1];
      for (var slot = 0; slot < slotCount; slot++) {
        final weight = (slot == from ? 1 - f : 0) + (slot == to ? f : 0);
        if (weight > 0) {
          frames[slot] = frames[slot].blend(overlay, weight * edge);
        }
      }
      return;
    }

    final double position;
    if (pattern == 'ping_pong') {
      final passes = _number(p, 'passes', 2);
      final phase = (context.progress * passes) % 2;
      position = (phase <= 1 ? phase : 2 - phase) * (slotCount - 1);
    } else {
      position = context.progress * (slotCount - 1);
    }
    final width = _number(p, 'width', 1);
    for (var slot = 0; slot < slotCount; slot++) {
      final weight = 1 - (slot - position).abs() / width;
      if (weight > 0) {
        frames[slot] = frames[slot].blend(overlay, weight * edge);
      }
    }
  }

  void _renderSurprise(_EventContext context, List<LightFrame> frames) {
    final p = context.event.parameters;
    final overlay = LightFrame(
      _color(p, 'color', LightColor.white),
      _number(p, 'brightness', 1),
    );
    final count = _number(p, 'count', 3).round().clamp(1, 64);
    final slice = context.event.duration.inMicroseconds / count;
    final now = context.local.inMicroseconds;

    // Draw every random value up front so the sequence does not depend on
    // which flash is currently active.
    for (var k = 0; k < count; k++) {
      final start = slice * (k + context.random.nextDouble() * 0.4);
      final length = slice * 0.55;
      final slot = context.random.nextInt(slotCount);
      if (now >= start && now < start + length) {
        final alpha = _flashEnvelope((now - start) / length);
        frames[slot] = frames[slot].blend(overlay, alpha * controls.intensity);
      }
    }
  }

  void _renderDim(_EventContext context, List<LightFrame> frames) {
    final level = _number(context.event.parameters, 'level', 0.1);
    final amount = _edgeFade(context.progress, 0.15);
    final factor = 1 + (level - 1) * amount;
    for (var slot = 0; slot < slotCount; slot++) {
      frames[slot] = frames[slot].withBrightness(frames[slot].brightness * factor);
    }
  }

  Iterable<int> _targets(Map<String, Object> p, math.Random random) {
    switch (p['target']) {
      case 'all':
        return Iterable<int>.generate(slotCount);
      case 'random_lights':
        final count = _number(p, 'count', 2).round().clamp(1, slotCount);
        return (List<int>.generate(slotCount, (i) => i)..shuffle(random))
            .take(count);
      case 'random_light':
      default:
        return [random.nextInt(slotCount)];
    }
  }

  /// A walk that mostly moves to a neighbouring light, sometimes jumps.
  List<int> _randomWalk(math.Random random, int length) {
    final path = <int>[random.nextInt(slotCount)];
    while (path.length < length) {
      final current = path.last;
      if (slotCount == 1) {
        path.add(current);
      } else if (random.nextDouble() < 0.7) {
        final direction = random.nextBool() ? 1 : -1;
        path.add((current + direction) % slotCount);
      } else {
        final jump = 1 + random.nextInt(slotCount - 1);
        path.add((current + jump) % slotCount);
      }
    }
    return path;
  }

  /// Deterministic pseudo-random value in 0..1 for a slot and channel.
  double _unit(int slot, int channel) =>
      _mix(seed, slot, channel) / 0x7FFFFFFF;

  /// Smooth value noise in -1..1.
  double _noise(int slot, double t) {
    final i = t.floor();
    final a = _mix(seed, slot * 7919 + i, 3) / 0x7FFFFFFF;
    final b = _mix(seed, slot * 7919 + i + 1, 3) / 0x7FFFFFFF;
    return (a + (b - a) * _smoothstep(t - i)) * 2 - 1;
  }
}

class _EventContext {
  _EventContext({
    required this.event,
    required this.local,
    required this.random,
  });

  final EffectEvent event;

  /// Time since the event started.
  final Duration local;
  final math.Random random;

  double get progress => event.duration == Duration.zero
      ? 1
      : (local.inMicroseconds / event.duration.inMicroseconds).clamp(0.0, 1.0);
}

/// Integer hash of three values, always in 0..0x7FFFFFFF.
int _mix(int a, int b, int c) {
  var h = (a * 0x27d4eb2d) ^ (b * 0x165667b1) ^ (c * 0x5bd1e995);
  h &= 0x7FFFFFFF;
  h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0x7FFFFFFF;
  h = ((h ^ (h >> 12)) * 0x297a2d39) & 0x7FFFFFFF;
  return (h ^ (h >> 15)) & 0x7FFFFFFF;
}

double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Fast attack (15%), smooth decay.
double _flashEnvelope(double progress) {
  if (progress <= 0 || progress >= 1) {
    return 0;
  }
  if (progress < 0.15) {
    return _smoothstep(progress / 0.15);
  }
  final decay = 1 - (progress - 0.15) / 0.85;
  return decay * decay;
}

/// 0 at the edges, 1 in the middle, with linear ramps of [ramp] each side.
double _edgeFade(double progress, double ramp) {
  if (progress < ramp) {
    return _smoothstep(progress / ramp);
  }
  if (progress > 1 - ramp) {
    return _smoothstep((1 - progress) / ramp);
  }
  return 1;
}

double _number(Map<String, Object> p, String key, double fallback) {
  final value = p[key];
  return value is num ? value.toDouble() : fallback;
}

Duration _millis(Map<String, Object> p, String key, int fallback) {
  final value = p[key];
  final millis = value is num ? value.round() : fallback;
  return Duration(milliseconds: millis < 50 ? 50 : millis);
}

LightColor _color(Map<String, Object> p, String key, LightColor fallback) {
  final value = p[key];
  return value is String ? LightColor.fromHex(value) : fallback;
}

List<LightColor> _palette(Map<String, Object> p) {
  final value = p['palette'];
  if (value is List && value.isNotEmpty) {
    return [for (final hex in value) LightColor.fromHex(hex as String)];
  }
  return const [LightColor.white];
}
