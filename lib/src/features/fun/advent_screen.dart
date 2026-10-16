import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../effects/read_along.dart';
import 'advent.dart';

/// The advent calendar: 24 doors in a jumbled order, each opening on its
/// day in December to a surprise of light.
class AdventScreen extends StatelessWidget {
  const AdventScreen({super.key});

  /// The doors' places on the calendar, jumbled as on a paper one.
  static const order = [
    7, 15, 2, 21, 11, 18, 4, 23, 9, 1, 14, 20, //
    6, 17, 12, 3, 24, 10, 19, 5, 13, 22, 8, 16,
  ];

  static IconData iconOf(int day) => day == Advent.days
      ? Icons.star
      : switch (Advent.motifOf(day)) {
          AdventMotif.snow => Icons.ac_unit,
          AdventMotif.star => Icons.auto_awesome,
          AdventMotif.bells => Icons.notifications_active_outlined,
          AdventMotif.candy => Icons.cake_outlined,
          AdventMotif.aurora => Icons.waves,
          AdventMotif.fire => Icons.local_fire_department_outlined,
        };

  Future<void> _open(BuildContext context, int day) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final today = scope.clock();
    await scope.preferences.openAdventDoor(day, today);
    final playback = scope.playback;
    await playback.switchEffect(Advent.effect(day, l10n.adventDay(day)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final today = scope.clock();
    final openUpTo = Advent.openUpTo(today);
    final year = today.month == 1 ? today.year - 1 : today.year;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.advent)),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.preferences, scope.playback]),
        builder: (context, _) {
          final playback = scope.playback;
          final playingDay = playback.status == PlaybackStatus.idle
              ? null
              : Advent.dayOf(playback.effect);
          final player = playback.player;
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(
                openUpTo == 0 ? l10n.adventLocked : l10n.adventDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (playingDay != null && player != null) ...[
                StreamBuilder<List<LightFrame>>(
                  stream: player.frames,
                  builder: (context, _) => ReadAlongCaption(
                    effect: playback.effect,
                    lines: Advent.narration(playingDay, l10n),
                    player: player,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              GridView.count(
                crossAxisCount: context.isWide ? 6 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final day in order)
                    _Door(
                      day: day,
                      opened: scope.preferences.isAdventOpened(day, today),
                      openable: day <= openUpTo,
                      onTap: () {
                        if (day <= openUpTo) {
                          _open(context, day);
                        } else {
                          final date = DateFormat.MMMMd(l10n.localeName)
                              .format(DateTime(year, 12, day));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.adventWait(date))));
                        }
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.day,
    required this.opened,
    required this.openable,
    required this.onTap,
  });

  final int day;
  final bool opened;
  final bool openable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = opened
        ? scheme.tertiaryContainer
        : openable
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = opened
        ? scheme.onTertiaryContainer
        : openable
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: context.l10n.adventDay(day),
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: opened
                ? Icon(AdventScreen.iconOf(day), color: foreground)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$day',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: foreground)),
                      if (!openable)
                        Icon(Icons.lock_outline, size: 14, color: foreground),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
