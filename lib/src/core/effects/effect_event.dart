class EffectEvent {
  const EffectEvent({
    required this.at,
    required this.type,
    this.duration = Duration.zero,
    this.parameters = const <String, Object>{},
  });

  final Duration at;
  final Duration duration;
  final String type;

  /// Type-specific settings. Any overlay event also accepts `chance`
  /// (0..1): the probability that it fires on a given pass of the timeline.
  final Map<String, Object> parameters;

  Duration get end => at + duration;

  bool isActiveAt(Duration t) => t >= at && t < end;
}

/// Event types understood by the renderer.
///
/// Kept as plain strings in [EffectEvent.type] so that effect definitions can
/// later be loaded from JSON without code changes.
abstract final class EffectEventTypes {
  /// Background palette that persists until the next ambient event starts.
  static const ambientPalette = 'ambient_palette';

  /// Short burst of light on one or all lights.
  static const magicFlash = 'magic_flash';

  /// A point of light moving between lights.
  static const travel = 'travel';

  /// Several flashes at random lights and random times.
  static const surprise = 'surprise';

  /// Temporary dimming of everything, e.g. "the room goes almost dark".
  static const dim = 'dim';

  /// A cluster of very short strikes on random lights.
  static const lightning = 'lightning';

  /// Pulses in time with a tempo (`bpm`), for party effects.
  static const beat = 'beat';

  /// Heavy steps from lamp to lamp: something walking through the room.
  static const footsteps = 'footsteps';

  /// Reacts to live audio from the microphone (Music Sync).
  static const music = 'music';

  /// Follows the colours of the TV, seen by the phone's camera (TV Sync).
  static const screen = 'screen';
}
