import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../app_scope.dart';
import '../common/app_text.dart';
import '../paths/path_story_screen.dart';
import '../library/scene_editor.dart';
import '../library/story_editor.dart';
import '../search/effect_search.dart';
import '../common/layout.dart';
import 'effect_palette.dart';
import 'player_route.dart';

class EffectListScreen extends StatelessWidget {
  const EffectListScreen({
    required this.kind,
    required this.title,
    super.key,
  });

  final EffectKind kind;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.preferences,
      builder: (context, _) => _build(context, scope.library.ofKind(kind)),
    );
  }

  Widget _build(BuildContext context, List<LightingEffect> effects) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.searchEffects,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EffectSearchScreen(kind: kind),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: switch (kind) {
        EffectKind.scene => FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SceneEditor()),
            ),
            icon: const Icon(Icons.palette_outlined),
            label: Text(l10n.newScene),
          ),
        EffectKind.story => FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StoryEditor()),
            ),
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(l10n.newStory),
          ),
        _ => null,
      },
      body: effects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.nothingHereYet,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : context.isWide
              ? _EffectGrid(effects, header: _header(kind))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, kind == EffectKind.interactive ? 20 : 96),
                  itemCount: effects.length + (_header(kind) == null ? 0 : 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final header = _header(kind);
                    if (header != null) {
                      return index == 0
                          ? header
                          : _EffectCard(effects[index - 1]);
                    }
                    return _EffectCard(effects[index]);
                  },
                ),
    );
  }
}

/// Tablets: cards in rows of two or three, each row as tall as its
/// tallest card, so no fixed height has to fit every language and font
/// size.
class _EffectGrid extends StatelessWidget {
  const _EffectGrid(this.effects, {this.header});

  final List<LightingEffect> effects;

  /// Shown above the cards, full width.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final insets = context.pageInsets(maxWidth: 1100, bottom: 96);
    final width = MediaQuery.sizeOf(context).width - insets.horizontal;
    final columns = (width / 360).floor().clamp(2, 3);
    final rows = [
      for (var i = 0; i < effects.length; i += columns)
        effects.sublist(i, (i + columns).clamp(0, effects.length)),
    ];
    final header = this.header;
    final offset = header == null ? 0 : 1;
    return ListView.separated(
      padding: insets,
      itemCount: rows.length + offset,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, item) {
        if (header != null && item == 0) {
          return header;
        }
        final index = item - offset;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: i < rows[index].length
                      ? _EffectCard(rows[index][i], compact: true)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Above the stories: the way to the choose-your-path stories.
Widget? _header(EffectKind kind) =>
    kind == EffectKind.story ? const _PathStoriesCard() : null;

class _PathStoriesCard extends StatelessWidget {
  const _PathStoriesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: ListTile(
        minVerticalPadding: 16,
        leading:
            Icon(Icons.alt_route, color: theme.colorScheme.onTertiaryContainer),
        title: Text(l10n.pathStories),
        subtitle: Text(l10n.pathStoriesSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PathStoriesScreen()),
        ),
      ),
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard(this.effect, {this.compact = false});

  final LightingEffect effect;

  /// In a grid: the description is cut after a few lines, so the rows
  /// stay even.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final colors = effectPalette(effect);
    final library = AppScope.of(context).library;
    final collection = library.isUserScene(effect.id)
        ? l10n.myScenes
        : library.isUserStory(effect.id)
            ? l10n.myStories
            : l10n.collectionName(effect);
    final description = l10n.effectDescription(effect);
    return Card(
      margin: compact ? EdgeInsets.zero : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openPlayer(context, effect),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors.length > 1 ? colors : [...colors, ...colors],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.effectName(effect),
                            style: theme.textTheme.titleMedium),
                      ),
                      if (effect.prefersStreaming)
                        Tooltip(
                          message: l10n.bestOnEntertainmentArea,
                          child: const Icon(Icons.bolt, size: 20),
                        ),
                    ],
                  ),
                  if (collection != null)
                    Text(collection, style: theme.textTheme.labelMedium),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: compact ? 3 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
