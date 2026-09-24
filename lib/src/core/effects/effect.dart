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
    this.isLooping = true,
  });

  final String id;
  final String name;
  final EffectKind kind;
  final List<EffectEvent> events;
  final bool isLooping;
}
