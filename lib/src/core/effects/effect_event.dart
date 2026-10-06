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
}
