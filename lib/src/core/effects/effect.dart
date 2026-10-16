import 'effect_event.dart';

enum EffectKind {
  scene,
  story,
  interactive,
}

/// An alternative colour set for an effect: the same timeline with every
/// palette swapped, e.g. Aurora in rose and gold.
class EffectVariant {
  const EffectVariant({
    required this.id,
    required this.name,
    required this.palette,
  });

  final String id;

  /// English name; the UI translates it by [id].
  final String name;

  /// `#RRGGBB` colours, in the order the effect cycles through them.
  final List<String> palette;
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
    this.prefersStreaming = false,
    this.variants = const [],
  });

  final String id;
  final String name;
  final EffectKind kind;
  final List<EffectEvent> events;
  final String description;

  /// Colour variants the user can pick; empty for effects whose colours
  /// are part of the story.
  final List<EffectVariant> variants;

  /// Thematic collection, e.g. "Magic & Fantasy" or "Nature".
  final String? collection;

  /// Length of one pass of the timeline. Defaults to the end of the last
  /// event.
  final Duration? loopDuration;
  final bool isLooping;

  /// Uses changes too fast for the REST API (strikes, beats); best played on
  /// an entertainment area.
  final bool prefersStreaming;

  /// Needs live audio: the player listens to the microphone while it plays.
  bool get usesMicrophone =>
      events.any((event) => event.type == EffectEventTypes.music);

  /// Needs the camera: the player follows the colours of the TV.
  bool get usesCamera =>
      events.any((event) => event.type == EffectEventTypes.screen);

  /// Contains sudden, repeated changes in brightness (lightning strikes,
  /// beats): the player warns photosensitive users before the first one.
  bool get hasRapidFlashes => events.any((event) => const {
        EffectEventTypes.lightning,
        EffectEventTypes.beat,
        EffectEventTypes.music,
      }.contains(event.type));

  /// This effect with every `palette` parameter replaced: ambient
  /// backgrounds, beats and Music Sync all follow the new colours; flashes
  /// and travels keep their own `color`.
  LightingEffect withPalette(List<String> palette) => LightingEffect(
        id: id,
        name: name,
        kind: kind,
        description: description,
        collection: collection,
        loopDuration: loopDuration,
        isLooping: isLooping,
        prefersStreaming: prefersStreaming,
        variants: variants,
        events: [
          for (final event in events)
            event.parameters.containsKey('palette')
                ? EffectEvent(
                    at: event.at,
                    duration: event.duration,
                    type: event.type,
                    parameters: {...event.parameters, 'palette': palette},
                  )
                : event,
        ],
      );

  /// The effect as variant [variantId] shows it; null or an unknown id
  /// gives the original colours.
  LightingEffect withVariant(String? variantId) {
    for (final variant in variants) {
      if (variant.id == variantId) {
        return withPalette(variant.palette);
      }
    }
    return this;
  }

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
