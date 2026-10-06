import 'effect_event.dart';

enum EffectKind {
  scene,
  story,
  interactive,
}

class LightingEffect {
  const LightingEffect({
    required this.id,
    required this.name,
    required this.kind,
    required this.events,
    this.description = '',
    this.collection,
    this.loopDuration,
    this.isLooping = true,
  });

  final String id;
  final String name;
  final EffectKind kind;
  final List<EffectEvent> events;
  final String description;

  /// Thematic collection, e.g. "Magic & Fantasy" or "Nature".
  final String? collection;

  /// Length of one pass of the timeline. Defaults to the end of the last
  /// event.
  final Duration? loopDuration;
  final bool isLooping;

  Duration get cycleLength {
    if (loopDuration != null) {
      return loopDuration!;
    }
    var end = Duration.zero;
    for (final event in events) {
      final eventEnd = event.at + event.duration;
      if (eventEnd > end) {
        end = eventEnd;
      }
    }
    return end;
  }
}
