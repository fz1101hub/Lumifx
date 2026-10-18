import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../effects/read_along.dart';
import 'tale.dart';

/// Makes up a bedtime story from a hero, a place and an adventure (or
/// at random), then tells it with the lights.
class TaleMakerScreen extends StatefulWidget {
  const TaleMakerScreen({this.playing, this.seed, super.key});

  /// The story already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  /// Fixes the surprises (tests).
  final int? seed;

  @override
  State<TaleMakerScreen> createState() => _TaleMakerScreenState();
}

class _TaleMakerScreenState extends State<TaleMakerScreen> {
  late final math.Random _random =
      widget.seed == null ? math.Random() : math.Random(widget.seed);
  late Tale _tale = switch (widget.playing) {
        final effect? => Tale.of(effect),
        null => null,
      } ??
      Tale.random(_random);
  late final _name = TextEditingController(text: _tale.name);
  late LightingEffect? _effect = widget.playing;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _defaultName =>
      TaleHero.values.any((h) => h.defaultName == _name.text.trim());

  void _choose({TaleHero? hero, TalePlace? place, TaleQuest? quest}) {
    setState(() {
      final nextHero = hero ?? _tale.hero;
      // A hero's own name follows the hero; a name the child typed stays.
      if (hero != null && _defaultName) {
        _name.text = nextHero.defaultName;
      }
      _tale = Tale(
        hero: nextHero,
        place: place ?? _tale.place,
        quest: quest ?? _tale.quest,
        name: _name.text,
      );
    });
  }

  void _surprise() {
    final keep = _defaultName ? null : _name.text;
    setState(() {
      _tale = Tale.random(_random, name: keep);
      _name.text = _tale.name;
    });
  }

  Future<void> _tell() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    var name = _name.text.trim();
    if (name.length > Tale.maxName) {
      name = name.substring(0, Tale.maxName).trim();
    }
    final tale = Tale(
      hero: _tale.hero,
      place: _tale.place,
      quest: _tale.quest,
      name: name.isEmpty ? _tale.hero.defaultName : name,
    );
    final effect = tale.effect(l10n);
    setState(() {
      _tale = tale;
      _effect = effect;
    });
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _another() async {
    _surprise();
    await _tell();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storyMaker)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final effect = _effect;
          final player = playback.player;
          if (effect != null &&
              playback.effect.id == effect.id &&
              player != null &&
              playback.status != PlaybackStatus.idle) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) => _telling(context, effect, playback),
            );
          }
          if (effect != null) {
            return _theEnd(context);
          }
          return _choices(context);
        },
      ),
    );
  }

  Widget _choices(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    Widget section(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        );
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.storyMakerDescription, style: theme.textTheme.bodyMedium),
        section(l10n.storyMakerHero, [
          for (final hero in TaleHero.values)
            ChoiceChip(
              avatar: Icon(hero.icon),
              label: Text(hero.label(l10n)),
              selected: _tale.hero == hero,
              onSelected: (_) => _choose(hero: hero),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          maxLength: Tale.maxName,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.storyMakerName,
            border: const OutlineInputBorder(),
          ),
        ),
        // The children's names, to make them the heroes.
        if (preferences.children.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in preferences.children)
                ActionChip(
                  avatar: const Icon(Icons.child_care),
                  label: Text(child.name),
                  onPressed: () => setState(() => _name.text = child.name),
                ),
            ],
          ),
        section(l10n.storyMakerPlace, [
          for (final place in TalePlace.values)
            ChoiceChip(
              avatar: Icon(place.icon),
              label: Text(place.label(l10n)),
              selected: _tale.place == place,
              onSelected: (_) => _choose(place: place),
            ),
        ]),
        section(l10n.storyMakerQuest, [
          for (final quest in TaleQuest.values)
            ChoiceChip(
              avatar: Icon(quest.icon),
              label: Text(quest.label(l10n)),
              selected: _tale.quest == quest,
              onSelected: (_) => _choose(quest: quest),
            ),
        ]),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_outlined),
            title: Text(l10n.readAloud),
            value: preferences.readAloud,
            onChanged: preferences.setReadAloud,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _surprise,
              icon: const Icon(Icons.casino_outlined),
              label: Text(l10n.storyMakerSurprise),
            ),
            FilledButton.icon(
              onPressed: _tell,
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(l10n.storyMakerTell),
            ),
          ],
        ),
      ],
    );
  }

  Widget _telling(
    BuildContext context,
    LightingEffect effect,
    PlaybackController playback,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(_tale.title(l10n),
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        ReadAlongCaption(
          effect: effect,
          lines: _tale.narration(l10n),
          player: playback.player,
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: playback.toggle,
            icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(playback.isPlaying ? l10n.pause : l10n.play),
          ),
        ),
      ],
    );
  }

  Widget _theEnd(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.pathTheEnd, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _another,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(l10n.storyMakerAnother),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await AppScope.of(context)
                        .preferences
                        .saveUserStory(_tale.toUserStory(l10n));
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                          SnackBar(content: Text(l10n.storyMakerSaved)));
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.storyMakerSave),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _effect = null),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.storyMaker),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
