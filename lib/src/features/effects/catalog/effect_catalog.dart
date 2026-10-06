import '../../../core/effects/effect.dart';
import 'builtin_scenes.dart';
import 'builtin_stories.dart';

/// Every effect shipped with the app.
final List<LightingEffect> effectCatalog = [
  ...builtinScenes,
  ...builtinStories,
];

List<LightingEffect> effectsOfKind(EffectKind kind) => [
      for (final effect in effectCatalog)
        if (effect.kind == kind) effect
    ];
