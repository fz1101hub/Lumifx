import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/speech/speaker.dart';
import '../bedtime/nap_light_screen.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import 'breathing_screen.dart';
import 'feelings.dart';

/// The feelings thermometer: a child taps how they feel, the room takes
/// that colour, the voice says it is okay and what may help.
class FeelingsScreen extends StatefulWidget {
  const FeelingsScreen({super.key});

  /// The gentle story offered to a sad child.
  static const storyId = 'enchanted_fairy';

  @override
  State<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends State<FeelingsScreen> {
  Feeling? _chosen;

  static String nameOf(AppLocalizations l10n, Feeling feeling) =>
      switch (feeling) {
        Feeling.happy => l10n.feelingHappy,
        Feeling.calm => l10n.feelingCalm,
        Feeling.sad => l10n.feelingSad,
        Feeling.angry => l10n.feelingAngry,
        Feeling.worried => l10n.feelingWorried,
        Feeling.tired => l10n.feelingTired,
      };

  static String sayingOf(AppLocalizations l10n, Feeling feeling) =>
      switch (feeling) {
        Feeling.happy => l10n.feelingSayHappy,
        Feeling.calm => l10n.feelingSayCalm,
        Feeling.sad => l10n.feelingSaySad,
        Feeling.angry => l10n.feelingSayAngry,
        Feeling.worried => l10n.feelingSayWorried,
        Feeling.tired => l10n.feelingSayTired,
      };

  static IconData iconOf(Feeling feeling) => switch (feeling) {
        Feeling.happy => Icons.sentiment_very_satisfied,
        Feeling.calm => Icons.sentiment_satisfied,
        Feeling.sad => Icons.sentiment_dissatisfied,
        Feeling.angry => Icons.mood_bad,
        Feeling.worried => Icons.sentiment_neutral,
        Feeling.tired => Icons.bedtime_outlined,
      };

  Future<void> _choose(Feeling feeling) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final playback = scope.playback;
    setState(() => _chosen = feeling);
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    // The words first: the light answers as they start, not after.
    if (scope.preferences.soundOn) {
      unawaited(() async {
        await scope.speaker.stop();
        await scope.speaker
            .speak(sayingOf(l10n, feeling), language, style: SpeechStyle.story);
      }());
    }
    playback.setSleepTimer(null);
    await playback.switchEffect(feeling.effect(nameOf(l10n, feeling)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _help(FeelingHelp help) async {
    final scope = AppScope.of(context);
    switch (help) {
      case FeelingHelp.breathe:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BreathingScreen()),
        );
      case FeelingHelp.rest:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NapLightScreen()),
        );
      case FeelingHelp.story:
        final story = scope.library.byId(FeelingsScreen.storyId);
        if (story != null) {
          await openPlayer(context, story);
        }
      case FeelingHelp.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    // In kids mode only what kids mode offers: breathing, not the player.
    final locked = scope.preferences.kidsLocked;
    final chosen = _chosen ?? Feeling.of(scope.playback.effect);
    final help = chosen?.help ?? FeelingHelp.none;
    final canHelp =
        help == FeelingHelp.breathe || (!locked && help != FeelingHelp.none);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feelings)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.feelingsDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: context.isWide ? 6 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final feeling in Feeling.values)
                _FeelingTile(
                  label: nameOf(l10n, feeling),
                  icon: iconOf(feeling),
                  color: LightColor.fromHex(feeling.color).toColor(),
                  selected: chosen == feeling,
                  onTap: () => _choose(feeling),
                ),
            ],
          ),
          if (chosen != null) ...[
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(
                sayingOf(l10n, chosen),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (canHelp) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: () => _help(help),
                icon: Icon(switch (help) {
                  FeelingHelp.breathe => Icons.spa_outlined,
                  FeelingHelp.story => Icons.auto_stories_outlined,
                  _ => Icons.bedtime_outlined,
                }),
                label: Text(switch (help) {
                  FeelingHelp.breathe => l10n.feelingBreathe,
                  FeelingHelp.story => l10n.feelingStory,
                  _ => l10n.feelingRest,
                }),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FeelingTile extends StatelessWidget {
  const _FeelingTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(color: theme.colorScheme.onSurface, width: 4)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: onColor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(color: onColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
