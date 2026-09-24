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
}
