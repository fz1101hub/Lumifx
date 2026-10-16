import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_palette.dart';
import '../effects/player_route.dart';
import '../library/effect_library.dart';

/// Lower case without accents, so "aurora" finds "Aurora" and "noel"
/// finds "Noël".
String foldForSearch(String text) {
  const from = 'àáâãäåāçćčèéêëēěìíîïīñńòóôõöøōùúûüūýÿžšß';
  const to = 'aaaaaaaccceeeeeeiiiiinnooooooouuuuuyyzss';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    out.write(i < 0 ? char : to[i]);
  }
  return out.toString();
}

/// Effects whose name, description or collection (in the app's language)
/// contain [query], optionally only of [kind] and [collection].
List<LightingEffect> searchEffects(
  AppLocalizations l10n,
  EffectLibrary library,
  String query, {
  EffectKind? kind,
  String? collection,
}) {
  final words = foldForSearch(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  return [
    for (final k in kind == null ? EffectKind.values : [kind])
      for (final effect in library.ofKind(k))
        if (collection == null ||
            _collectionOf(l10n, library, effect) == collection)
          if (words.every(foldForSearch([
            l10n.effectName(effect),
            l10n.effectDescription(effect),
            _collectionOf(l10n, library, effect) ?? '',
          ].join(' '))
              .contains))
            effect,
  ];
}

String? _collectionOf(
        AppLocalizations l10n, EffectLibrary library, LightingEffect effect) =>
    library.isUserScene(effect.id)
        ? l10n.myScenes
        : library.isUserStory(effect.id)
            ? l10n.myStories
            : l10n.collectionName(effect);

/// Search over every effect, with chips to narrow by kind and collection.
class EffectSearchScreen extends StatefulWidget {
  const EffectSearchScreen({this.kind, super.key});

  /// Start narrowed to one kind (from a list screen).
  final EffectKind? kind;

  @override
  State<EffectSearchScreen> createState() => _EffectSearchScreenState();
}

class _EffectSearchScreenState extends State<EffectSearchScreen> {
  final _query = TextEditingController();
  late EffectKind? _kind = widget.kind;
  String? _collection;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _kindName(AppLocalizations l10n, EffectKind kind) => switch (kind) {
        EffectKind.scene => l10n.scenes,
        EffectKind.story => l10n.stories,
        EffectKind.interactive => l10n.interactive,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_query, scope.preferences]),
      builder: (context, _) {
        final library = scope.library;
        final collections = <String>{
          for (final k in _kind == null ? EffectKind.values : [_kind!])
            for (final effect in library.ofKind(k))
              if (_collectionOf(l10n, library, effect) case final c?) c,
        }.toList()
          ..sort();
        if (_collection != null && !collections.contains(_collection)) {
          _collection = null;
        }
        final results = searchEffects(
          l10n,
          library,
          _query.text,
          kind: _kind,
          collection: _collection,
        );
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchEffects,
                border: InputBorder.none,
              ),
            ),
            actions: [
              if (_query.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.clearSearch,
                  icon: const Icon(Icons.close),
                  onPressed: _query.clear,
                ),
            ],
          ),
          body: ListView(
            padding: context.pageInsets(top: 8),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final kind in EffectKind.values)
                    FilterChip(
                      label: Text(_kindName(l10n, kind)),
                      selected: _kind == kind,
                      onSelected: (on) =>
                          setState(() => _kind = on ? kind : null),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final collection in collections)
                    FilterChip(
                      label: Text(collection),
                      selected: _collection == collection,
                      onSelected: (on) =>
                          setState(() => _collection = on ? collection : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.noEffectsFound,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              for (final effect in results)
                ListTile(
                  key: ValueKey(effect.id),
                  contentPadding: EdgeInsets.zero,
                  leading: _Swatch(effect),
                  title: Text(l10n.effectName(effect)),
                  subtitle: Text(
                    [
                      _kindName(l10n, effect.kind),
                      if (_collectionOf(l10n, library, effect) case final c?) c,
                    ].join(' · '),
                  ),
                  onTap: () => openPlayer(context, effect),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.effect);

  final LightingEffect effect;

  @override
  Widget build(BuildContext context) {
    final colors = effectPalette(effect);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: colors.length > 1 ? colors : [...colors, ...colors],
        ),
      ),
    );
  }
}
