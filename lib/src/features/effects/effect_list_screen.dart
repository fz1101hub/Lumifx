import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../app_scope.dart';
import '../common/app_text.dart';
import '../library/scene_editor.dart';
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
      floatingActionButton: kind == EffectKind.scene
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SceneEditor()),
              ),
              icon: const Icon(Icons.palette_outlined),
              label: Text(l10n.newScene),
            )
          : null,
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
              ? _EffectGrid(effects)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, kind == EffectKind.scene ? 96 : 20),
                  itemCount: effects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _EffectCard(effects[index]),
                ),
    );
  }
}

/// Tablets: cards in rows of two or three, each row as tall as its
/// tallest card, so no fixed height has to fit every language and font
/// size.
class _EffectGrid extends StatelessWidget {
  const _EffectGrid(this.effects);

  final List<LightingEffect> effects;

  @override
  Widget build(BuildContext context) {
    final insets = context.pageInsets(maxWidth: 1100, bottom: 96);
    final width = MediaQuery.sizeOf(context).width - insets.horizontal;
    final columns = (width / 360).floor().clamp(2, 3);
    final rows = [
      for (var i = 0; i < effects.length; i += columns)
        effects.sublist(i, (i + columns).clamp(0, effects.length)),
    ];
    return ListView.separated(
      padding: insets,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => IntrinsicHeight(
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
    final collection = AppScope.of(context).library.isUserScene(effect.id)
        ? l10n.myScenes
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
