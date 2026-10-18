import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/sound/melody.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'light_piano.dart';
import 'music_box_screen.dart';

/// The light piano: each key plays a music-box note on the phone and
/// lights a lamp in its colour; or learn a tune by following the glowing
/// key.
class LightPianoScreen extends StatefulWidget {
  const LightPianoScreen({super.key});

  @override
  State<LightPianoScreen> createState() => _LightPianoScreenState();
}

class _LightPianoScreenState extends State<LightPianoScreen> {
  PianoLesson? _lesson;
  int? _pressed;
  var _missed = false;

  Future<void> _ensurePlaying(PlaybackController playback) async {
    final background = pianoBackground(context.l10n.piano);
    if (playback.effect.id != background.id ||
        playback.status == PlaybackStatus.idle) {
      await playback.switchEffect(background);
    }
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _press(int index) async {
    final playback = AppScope.of(context).playback;
    final key = pianoKeys[index];
    unawaited(HapticFeedback.selectionClick());
    unawaited(playback.note(key.midi, Instrument.musicBox));
    final lesson = _lesson;
    setState(() {
      _pressed = index;
      if (lesson != null && !lesson.isFinished) {
        _missed = !lesson.press(index);
      }
    });
    await _ensurePlaying(playback);
    playback.flash(LightColor.fromHex(key.color),
        length: const Duration(milliseconds: 900),
        at: index / (pianoKeys.length - 1));
    if (lesson != null && lesson.isFinished && !_missed) {
      unawaited(HapticFeedback.heavyImpact());
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted && _pressed == index) {
      setState(() => _pressed = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    final language = Localizations.localeOf(context).languageCode;
    final lesson = _lesson;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.piano)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: context.pageInsets(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!preferences.soundOn)
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: SwitchListTile(
                      secondary: const Icon(Icons.volume_off_outlined),
                      title: Text(l10n.musicSoundsOff),
                      value: preferences.soundOn,
                      onChanged: preferences.setSoundOn,
                    ),
                  ),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.piano_outlined),
                      label: Text(l10n.pianoFree),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.school_outlined),
                      label: Text(l10n.pianoLearn),
                    ),
                  ],
                  selected: {lesson != null},
                  onSelectionChanged: (learn) => setState(() {
                    _missed = false;
                    _lesson =
                        learn.first ? PianoLesson(pianoSongs.first) : null;
                  }),
                ),
                const SizedBox(height: 12),
                if (lesson != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final song in pianoSongs)
                        ChoiceChip(
                          label: Text(MusicBoxScreen.nameOf(l10n, song)),
                          selected: lesson.melody.id == song.id,
                          onSelected: (_) => setState(() {
                            _missed = false;
                            _lesson = PianoLesson(song);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      lesson.isFinished
                          ? l10n.pianoBravo
                          : '${l10n.pianoNext} · '
                              '${l10n.pianoProgress(lesson.done, lesson.total)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (lesson.isFinished)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(
                            () => _lesson = PianoLesson(lesson.melody)),
                        icon: const Icon(Icons.replay),
                        label: Text(l10n.gameAgain),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, key) in pianoKeys.indexed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _Key(
                              color: LightColor.fromHex(key.color).toColor(),
                              label: pianoNoteName(language, i),
                              pressed: _pressed == i,
                              glowing: lesson?.next == i,
                              onTap: () => _press(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.color,
    required this.label,
    required this.pressed,
    required this.glowing,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool pressed;
  final bool glowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      selected: glowing,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: pressed ? color : Color.lerp(color, Colors.black, 0.45),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: glowing
              ? Border.all(color: theme.colorScheme.onSurface, width: 4)
              : null,
          boxShadow: pressed || glowing
              ? [BoxShadow(color: color, blurRadius: 18, spreadRadius: 1)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: onTap,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
