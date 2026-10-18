import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/sound/melodies.dart';
import '../../core/sound/melody.dart';
import '../../core/sound/soundscape.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'melody_lights.dart';

/// Lullabies on a music box, or a Christmas light show with carols: the
/// tune plays on the phone and every note lights a lamp.
class MusicBoxScreen extends StatefulWidget {
  const MusicBoxScreen({required this.festive, super.key});

  /// Carols (a light show) rather than lullabies.
  final bool festive;

  static String nameOf(AppLocalizations l10n, Melody melody) =>
      switch (melody.id) {
        'brahms' => l10n.melodyBrahms,
        'twinkle' => l10n.melodyTwinkle,
        'frere_jacques' => l10n.melodyFrereJacques,
        'jingle_bells' => l10n.melodyJingleBells,
        'silent_night' => l10n.melodySilentNight,
        'au_clair' => l10n.melodyAuClair,
        'mary_lamb' => l10n.melodyMaryLamb,
        'hot_cross_buns' => l10n.melodyHotCrossBuns,
        'ode_to_joy' => l10n.melodyOdeToJoy,
        _ => l10n.melodyMerryChristmas,
      };

  @override
  State<MusicBoxScreen> createState() => _MusicBoxScreenState();
}

class _MusicBoxScreenState extends State<MusicBoxScreen> {
  int _times = 3;
  bool _switchOff = true;

  List<Melody> get _melodies => widget.festive ? carols : lullabies;

  Future<void> _play(Melody melody) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final times = widget.festive ? 1 : _times;
    final effect = melodyEffect(melody,
        times: times, name: MusicBoxScreen.nameOf(l10n, melody));
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
    // A lullaby ends with the lights fading out and switching off.
    if (!widget.festive && _switchOff) {
      playback.setSleepTimer(effect.cycleLength);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final playback = scope.playback;
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.festive ? l10n.christmasShow : l10n.lullabies),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([playback, preferences]),
        builder: (context, _) {
          final playing = playback.status != PlaybackStatus.idle
              ? soundscapeOf(playback.effect).melody?.id
              : null;
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(
                widget.festive
                    ? l10n.christmasShowDescription
                    : l10n.lullabiesDescription,
                style: theme.textTheme.bodyMedium,
              ),
              if (!preferences.soundOn) ...[
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.volume_off_outlined),
                    title: Text(l10n.musicSoundsOff),
                    value: preferences.soundOn,
                    onChanged: preferences.setSoundOn,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!widget.festive) ...[
                Text(l10n.lullabyTimes, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final times in const [1, 3, 5])
                      ChoiceChip(
                        label: Text(l10n.lullabyTimesCount(times)),
                        selected: _times == times,
                        onSelected: (_) => setState(() => _times = times),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.bedtime_outlined),
                  title: Text(l10n.lullabySwitchOff),
                  value: _switchOff,
                  onChanged: (on) => setState(() => _switchOff = on),
                ),
                const SizedBox(height: 8),
              ],
              for (final melody in _melodies)
                Card(
                  child: ListTile(
                    leading: Icon(widget.festive
                        ? Icons.celebration_outlined
                        : Icons.music_note_outlined),
                    title: Text(MusicBoxScreen.nameOf(l10n, melody)),
                    subtitle: Text(_minutes(l10n, melody)),
                    selected: playing == melody.id,
                    trailing: playing == melody.id
                        ? IconButton(
                            tooltip: l10n.stop,
                            icon: const Icon(Icons.stop),
                            onPressed: playback.stop,
                          )
                        : IconButton(
                            tooltip: l10n.play,
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _play(melody),
                          ),
                    onTap: () => _play(melody),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _minutes(AppLocalizations l10n, Melody melody) {
    final times = widget.festive ? 1 : _times;
    final seconds = (melody.length * times).inSeconds;
    return seconds < 60
        ? l10n.melodySeconds(seconds)
        : l10n.sleepTimerMinutes((seconds / 60).ceil());
  }
}

/// Whether [effect] plays a melody (for the mini-player).
bool isMelodyEffect(LightingEffect effect) =>
    effect.id.startsWith(melodyEffectPrefix);
