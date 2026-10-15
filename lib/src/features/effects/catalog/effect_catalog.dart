import '../../../core/effects/effect.dart';
import 'builtin_adventures.dart';
import 'builtin_interactive.dart';
import 'builtin_scenes.dart';
import 'builtin_seasonal.dart';
import 'builtin_stories.dart';

/// Every effect shipped with the app.
final List<LightingEffect> effectCatalog = [
  ...builtinScenes,
  ...builtinStories,
  ...builtinAdventures,
  ...builtinSeasonal,
  ...builtinInteractive,
];

LightingEffect? effectById(String id) =>
    effectCatalog.where((effect) => effect.id == id).firstOrNull;

List<LightingEffect> effectsOfKind(EffectKind kind) => [
      for (final effect in effectCatalog)
        if (effect.kind == kind) effect
    ];
