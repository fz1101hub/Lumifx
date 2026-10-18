import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'cinema.dart';

/// A film night: three buttons for the start, the intermission and the
/// end, and the lights follow like at the cinema.
class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  var _withGlow = true;

  Future<void> _play(LightingEffect effect) async {
    final playback = AppScope.of(context).playback;
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
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cinema)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final phase = playback.status == PlaybackStatus.idle
              ? null
              : Cinema.phaseOf(playback.effect);
          Widget step(
            CinemaPhase target,
            IconData icon,
            String label,
            LightingEffect Function() effect,
          ) {
            final now = phase == target;
            final style = FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(72),
              textStyle: theme.textTheme.titleLarge,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: now
                  ? FilledButton.icon(
                      style: style,
                      onPressed: () => _play(effect()),
                      icon: Icon(icon, size: 32),
                      label: Text(label),
                    )
                  : FilledButton.tonalIcon(
                      style: style,
                      onPressed: () => _play(effect()),
                      icon: Icon(icon, size: 32),
                      label: Text(label),
                    ),
            );
          }

          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.cinemaDescription, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.cinemaGlow),
                subtitle: Text(l10n.cinemaGlowSubtitle),
                value: _withGlow,
                onChanged: (on) {
                  setState(() => _withGlow = on);
                  if (phase == CinemaPhase.film) {
                    _play(Cinema.film(l10n.cinema, withGlow: on));
                  }
                },
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (phase) {
                    CinemaPhase.film => l10n.cinemaNowFilm,
                    CinemaPhase.intermission => l10n.cinemaNowIntermission,
                    CinemaPhase.end => l10n.cinemaNowEnd,
                    null => '',
                  },
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              step(
                CinemaPhase.film,
                Icons.movie_outlined,
                phase == CinemaPhase.intermission
                    ? l10n.cinemaResume
                    : l10n.cinemaStart,
                () => Cinema.film(l10n.cinema, withGlow: _withGlow),
              ),
              step(
                CinemaPhase.intermission,
                Icons.local_cafe_outlined,
                l10n.cinemaIntermission,
                () => Cinema.intermission(l10n.cinema),
              ),
              step(
                CinemaPhase.end,
                Icons.wb_twilight_outlined,
                l10n.cinemaEnd,
                () => Cinema.end(l10n.cinema),
              ),
            ],
          );
        },
      ),
    );
  }
}
