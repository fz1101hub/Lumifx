import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/player_route.dart';
import '../library/preferences_controller.dart';

/// Bedtime in one tap: pick a calm story (remembered for next time), how
/// long it plays and how long the night glow lasts, then start. The
/// player opens with the story's words to read along.
class BedtimeScreen extends StatefulWidget {
  const BedtimeScreen({super.key});

  @override
  State<BedtimeScreen> createState() => _BedtimeScreenState();
}

class _BedtimeScreenState extends State<BedtimeScreen> {
  bool _starting = false;

  /// Stories without lightning or beats: nothing should flash at bedtime.
  static List<LightingEffect> _calmStories(BuildContext context) => [
        for (final effect
            in AppScope.of(context).library.ofKind(EffectKind.story))
          if (!effect.hasRapidFlashes) effect,
      ];

  Future<void> _start(LightingEffect story) async {
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    setState(() => _starting = true);
    await scope.playback.startBedtime(
      story,
      storyFor: Duration(minutes: preferences.bedtimeStoryMinutes),
      glowFor: Duration(minutes: preferences.bedtimeGlowMinutes),
      brightness: preferences.bedtimeBrightness,
    );
    if (!mounted) {
      return;
    }
    setState(() => _starting = false);
    if (scope.playback.inBedtime) {
      await Navigator.of(context).pushReplacement(playerRoute(story));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bedtime)),
      body: ListenableBuilder(
        listenable: Listenable.merge([preferences, scope.playback]),
        builder: (context, _) {
          final stories = _calmStories(context);
          final story = stories
                  .where((e) => e.id == preferences.bedtimeStory)
                  .firstOrNull ??
              stories.first;
          final place = scope.playback.targetName ?? l10n.previewOnly;
          return ListView(
            padding: context.pageInsets(),
            children: [
              Icon(Icons.bedtime_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.bedtimeDescription, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey(story.id),
                initialValue: story.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.bedtimeStory,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final effect in stories)
                    DropdownMenuItem(
                      value: effect.id,
                      child: Text(
                        l10n.effectName(effect),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => preferences.setBedtime(story: id),
              ),
              const SizedBox(height: 24),
              Text(l10n.bedtimeStoryFor, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _MinuteChoices(
                choices: PreferencesController.bedtimeStoryChoices,
                selected: preferences.bedtimeStoryMinutes,
                onSelected: (m) => preferences.setBedtime(storyMinutes: m),
              ),
              const SizedBox(height: 20),
              Text(l10n.bedtimeGlowFor, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _MinuteChoices(
                choices: PreferencesController.bedtimeGlowChoices,
                selected: preferences.bedtimeGlowMinutes,
                onSelected: (m) => preferences.setBedtime(glowMinutes: m),
              ),
              const SizedBox(height: 20),
              Text(l10n.brightness, style: theme.textTheme.titleSmall),
              Slider(
                value: preferences.bedtimeBrightness,
                min: 0.1,
                divisions: 9,
                label: '${(preferences.bedtimeBrightness * 100).round()} %',
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                onChanged: (v) => preferences.setBedtime(brightness: v),
              ),
              const SizedBox(height: 8),
              Text(l10n.bedtimeWhere(place), style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _starting ? null : () => _start(story),
                icon: _starting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bedtime),
                label: Text(l10n.startBedtime),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MinuteChoices extends StatelessWidget {
  const _MinuteChoices({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<int> choices;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final minutes in choices)
          ChoiceChip(
            label: Text(context.l10n.sleepTimerMinutes(minutes)),
            selected: minutes == selected,
            onSelected: (_) => onSelected(minutes),
          ),
      ],
    );
  }
}
