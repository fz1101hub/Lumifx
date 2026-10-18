import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../fun/noise_light.dart';
import '../kids/kids_mode.dart';
import 'effect_palette.dart';
import 'playback_controller.dart';
import 'player_route.dart';

/// A bar at the bottom of every screen while an effect plays, except on
/// that effect's own player: what plays, where, pause and stop, and a tap
/// to open the player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.controller,
    required this.onOpen,
    super.key,
  });

  final PlaybackController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final effect = c.effect;
    final colors = effectPalette(c.effectToPlay);
    final where = c.targetName ?? l10n.previewOnly;
    final playlist = c.playlist;
    final subtitle = [
      if (playlist != null) playlist.name,
      where,
      if (c.isFadingOut) l10n.sleepTimerFading,
    ].join(' · ');
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors:
                          colors.length > 1 ? colors : [...colors, ...colors],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.effectName(effect),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (playlist != null)
                  _BarButton(
                    label: l10n.nextEffect,
                    icon: Icons.skip_next,
                    onPressed: c.isBusy ? null : c.nextInPlaylist,
                  ),
                _BarButton(
                  label: c.isPlaying ? l10n.pause : l10n.play,
                  icon: c.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: c.isBusy ? null : c.toggle,
                ),
                _BarButton(
                  label: l10n.stop,
                  icon: Icons.stop,
                  onPressed: c.stop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon button labelled for screen readers. No tooltip: the bar sits
/// below the navigator, outside the overlay tooltips need.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        child: IconButton(icon: Icon(icon), onPressed: onPressed),
      );
}

/// Puts the [MiniPlayer] under the app's pages while something plays.
/// The page area keeps the same place in the tree whether the bar shows or
/// not, so the navigator below never loses its pages.
class PlaybackShell extends StatelessWidget {
  const PlaybackShell({
    required this.controller,
    required this.routes,
    required this.onOpen,
    required this.child,
    super.key,
  });

  final PlaybackController controller;
  final RouteTracker routes;
  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, routes]),
      builder: (context, page) {
        final shownId = playerEffectId(routes.topRouteName);
        // Kids mode has its own stop, and no way out to the player; the
        // noise light plays only while its own screen is open.
        final visible = controller.status != PlaybackStatus.idle &&
            !isKidsModeRoute(routes.topRouteName) &&
            NoiseZone.of(controller.effect) == null &&
            (shownId == null || !controller.isShownBy(shownId));
        return Column(
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: visible,
                child: page!,
              ),
            ),
            if (visible) MiniPlayer(controller: controller, onOpen: onOpen),
          ],
        );
      },
      child: child,
    );
  }
}
