import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import 'catalog/effect_catalog.dart';
import 'effect_palette.dart';
import 'effect_player_screen.dart';

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
    final effects = effectsOfKind(kind);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: effects.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Interactive experiences are coming soon.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: effects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _EffectCard(effects[index]),
            ),
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard(this.effect);

  final LightingEffect effect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = effectPalette(effect);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EffectPlayerScreen(effect: effect),
          ),
        ),
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
                        child: Text(effect.name,
                            style: theme.textTheme.titleMedium),
                      ),
                      if (effect.prefersStreaming)
                        const Tooltip(
                          message: 'Best on an entertainment area',
                          child: Icon(Icons.bolt, size: 20),
                        ),
                    ],
                  ),
                  if (effect.collection != null)
                    Text(effect.collection!,
                        style: theme.textTheme.labelMedium),
                  if (effect.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(effect.description, style: theme.textTheme.bodyMedium),
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
