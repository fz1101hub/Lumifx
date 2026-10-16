import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../effects/read_along.dart';
import 'path_story.dart';

/// The choose-your-path stories, to pick one.
class PathStoriesScreen extends StatelessWidget {
  const PathStoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pathStories)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.pathStoriesDescription,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final story in pathStories)
            Card(
              child: ListTile(
                minVerticalPadding: 16,
                leading: const Icon(Icons.alt_route),
                title: Text(story.title(l10n)),
                subtitle: Text(story.description(l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PathStoryScreen(story: story),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One choose-your-path story: its words in time with the lights and, at
/// each turn, two big buttons to choose the way.
class PathStoryScreen extends StatefulWidget {
  const PathStoryScreen({required this.story, super.key});

  final PathStory story;

  @override
  State<PathStoryScreen> createState() => _PathStoryScreenState();
}

class _PathStoryScreenState extends State<PathStoryScreen> {
  PathPart? _part;
  LightingEffect? _effect;

  Future<void> _play(PathPart part) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final effect = widget.story.effectOf(part, l10n);
    setState(() {
      _part = part;
      _effect = effect;
    });
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(widget.story.title(l10n))),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final part = _part;
          final effect = _effect;
          final player = playback.player;
          final running = part != null &&
              effect != null &&
              playback.effect.id == effect.id &&
              player != null &&
              playback.status != PlaybackStatus.idle;
          if (running) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) =>
                  _playing(context, part, effect, playback),
            );
          }
          if (part != null && part.isEnding) {
            return _theEnd(context);
          }
          return _intro(context);
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    return ListView(
      padding: context.pageInsets(),
      children: [
        Icon(Icons.alt_route, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(widget.story.description(l10n), style: theme.textTheme.bodyLarge),
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
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _play(widget.story.start),
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.timerStart),
        ),
      ],
    );
  }

  Widget _playing(
    BuildContext context,
    PathPart part,
    LightingEffect effect,
    PlaybackController playback,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final choices = part.choices;
    final waiting = choices != null &&
        playback.player!.position >= Duration(seconds: part.seconds);
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 8),
        ReadAlongCaption(
          effect: effect,
          lines: PathStory.narrationOf(part, l10n),
          player: playback.player,
        ),
        const SizedBox(height: 24),
        if (waiting) ...[
          for (final choice in [choices.$1, choices.$2]) ...[
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                textStyle: theme.textTheme.titleLarge,
              ),
              onPressed: () => _play(widget.story.part(choice.next)),
              icon: Icon(choice.icon, size: 32),
              label: Text(choice.label(l10n)),
            ),
            const SizedBox(height: 12),
          ],
        ] else
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
                  onPressed: () => _play(widget.story.start),
                  icon: const Icon(Icons.alt_route),
                  label: Text(l10n.pathPlayAgain),
                ),
                OutlinedButton(
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
