import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'goal.dart';

/// Goal! Pick a team (or make one from up to three colours), then the big
/// button bursts the room into its colours.
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  static String teamName(AppLocalizations l10n, GoalTeam team) =>
      switch (team) {
        GoalTeam.italy => l10n.goalTeamItaly,
        GoalTeam.germany => l10n.goalTeamGermany,
        GoalTeam.france => l10n.goalTeamFrance,
        GoalTeam.spain => l10n.goalTeamSpain,
        GoalTeam.netherlands => l10n.goalTeamNetherlands,
        GoalTeam.brazil => l10n.goalTeamBrazil,
        GoalTeam.japan => l10n.goalTeamJapan,
        GoalTeam.england => l10n.goalTeamEngland,
      };

  /// Plays the goal for the team chosen last (from the screen, a link).
  static Future<void> celebrate(
      PlaybackController playback, String name, String? choice) async {
    playback.setSleepTimer(null);
    await playback.switchEffect(Goal.effect(name, Goal.colorsOfChoice(choice)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  List<String>? _own;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    final choice = preferences.goalTeam ?? GoalTeam.italy.name;
    final isOwn = GoalTeam.values.asNameMap()[choice] == null;
    final own = _own ?? (isOwn ? Goal.colorsOfChoice(choice) : <String>[]);
    // The colours side by side in one small round badge.
    Widget dots(List<String> colors) => ClipOval(
          child: SizedBox.square(
            dimension: 18,
            child: Row(
              children: [
                for (final c in colors)
                  Expanded(
                    child: ColoredBox(color: LightColor.fromHex(c).toColor()),
                  ),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.goal)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.goalDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                unawaited(HapticFeedback.heavyImpact());
                unawaited(GoalScreen.celebrate(
                    scope.playback, l10n.goal, preferences.goalTeam));
              },
              child: Text(l10n.goalButton,
                  style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final team in GoalTeam.values)
                ChoiceChip(
                  avatar: dots(team.colors),
                  label: Text(GoalScreen.teamName(l10n, team)),
                  selected: choice == team.name,
                  onSelected: (_) {
                    unawaited(preferences.setGoalTeam(team.name));
                    setState(() => _own = null);
                  },
                ),
              ChoiceChip(
                avatar: own.isEmpty ? null : dots(own),
                label: Text(l10n.goalOwnTeam),
                selected: isOwn,
                onSelected: (_) => setState(() => _own = own),
              ),
            ],
          ),
          if (isOwn || _own != null) ...[
            const SizedBox(height: 16),
            Text(l10n.goalOwnColours, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, color) in Goal.swatches.indexed)
                  Semantics(
                    button: true,
                    selected: own.contains(color),
                    label: l10n.sceneSwatch(i + 1),
                    excludeSemantics: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        final next = [...own];
                        if (!next.remove(color) && next.length < 3) {
                          next.add(color);
                        }
                        setState(() => _own = next);
                        if (next.isNotEmpty) {
                          unawaited(preferences.setGoalTeam(next.join(',')));
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LightColor.fromHex(color).toColor(),
                          border: Border.all(
                            color: own.contains(color)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outlineVariant,
                            width: own.contains(color) ? 4 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.goalLinkHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
