import 'dart:async';
import 'dart:math' as math;

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
import '../library/sharing.dart';
import '../links/app_link.dart';
import 'my_tune.dart';
import 'music_box_screen.dart';

/// The light piano: each key plays a music-box note on the phone and
/// lights a lamp in its colour; or learn a tune by following the glowing
/// key.
class LightPianoScreen extends StatefulWidget {
  const LightPianoScreen({this.seed, super.key});

  /// Fixes the tunes of Repeat after me (tests).
  final int? seed;

  @override
  State<LightPianoScreen> createState() => _LightPianoScreenState();
}

enum _Mode { free, learn, echo }

/// Where Repeat after me is.
enum _Echo { listen, yourTurn, bravo, oops }

class _LightPianoScreenState extends State<LightPianoScreen> {
  var _mode = _Mode.free;
  PianoLesson? _lesson;
  int? _pressed;
  var _missed = false;

  late final _echo =
      PianoEcho(widget.seed == null ? null : math.Random(widget.seed));
  var _echoing = _Echo.listen;

  /// What was played while recording: when, and which key.
  final _recorded = <(Duration, int)>[];
  Stopwatch? _recording;

  @override
  void initState() {
    super.initState();
    // The keys' notes made ahead: the first press sounds with its light.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(AppScope.of(context).playback.prepareSounds(
          midis: [for (final key in pianoKeys) key.midi],
        ));
      }
    });
  }

  var _playingBack = false;

  /// Bumped to stop a play-back.
  var _generation = 0;

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      if (_recording != null) {
        _recording = null;
      } else {
        _recorded.clear();
        _recording = Stopwatch()..start();
      }
    });
  }

  /// Plays back what was recorded (or a kept tune), with its own timing.
  Future<void> _playBack([List<(Duration, int)>? notes]) async {
    final generation = ++_generation;
    setState(() => _playingBack = true);
    var at = Duration.zero;
    for (final (time, key) in [...notes ?? _recorded]) {
      await Future<void>.delayed(time - at);
      at = time;
      if (!mounted || generation != _generation) {
        return;
      }
      unawaited(_press(key, replay: true));
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted && generation == _generation) {
      setState(() => _playingBack = false);
    }
  }

  /// Keeps what was just recorded, under a name.
  Future<void> _saveTune() async {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TuneNameDialog(
          initial: l10n.pianoTuneDefaultName(preferences.myTunes.length + 1)),
    );
    final tune = name == null
        ? null
        : MyTune.decode(
            name, MyTune(name: name, notes: [..._recorded]).encoded);
    if (tune != null) {
      await preferences.saveTune(tune);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Share or delete a kept tune.
  Future<void> _tuneMenu(MyTune tune) async {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.pianoShareTune),
              onTap: () => Navigator.of(context).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.pianoDeleteTune),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (choice == 'delete') {
      await preferences.deleteTune(tune.name);
      if (mounted) {
        setState(() {});
      }
    } else if (choice == 'share') {
      await showDialog<void>(
        context: context,
        builder: (_) => ShareDialog(
          title: tune.name,
          link: AppLink.tune(tune.name, tune.encoded),
        ),
      );
    }
  }

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

  /// Plays the tune of Repeat after me, then lets the child play it back.
  Future<void> _playEcho() async {
    final generation = ++_generation;
    setState(() => _echoing = _Echo.listen);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (final key in _echo.keys) {
      if (!mounted || generation != _generation) {
        return;
      }
      unawaited(_press(key, replay: true));
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    if (mounted && generation == _generation) {
      setState(() => _echoing = _Echo.yourTurn);
    }
  }

  /// A key played back in Repeat after me.
  Future<void> _echoPress(int index) async {
    if (_echoing != _Echo.yourTurn) {
      return;
    }
    final result = _echo.press(index);
    unawaited(_press(index, replay: true));
    if (result == EchoPress.right) {
      return;
    }
    if (result == EchoPress.done) {
      AppScope.of(context).preferences.recordPianoEcho(_echo.keys.length);
    }
    final generation = ++_generation;
    setState(
        () => _echoing = result == EchoPress.done ? _Echo.bravo : _Echo.oops);
    unawaited(result == EchoPress.done
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.mediumImpact());
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || generation != _generation || _mode != _Mode.echo) {
      return;
    }
    if (result == EchoPress.done) {
      _echo.grow();
    } else {
      _echo.again();
    }
    await _playEcho();
  }

  void _setMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _missed = false;
      _recording = null;
      _generation++;
      _playingBack = false;
      _lesson = mode == _Mode.learn ? PianoLesson(pianoSongs.first) : null;
    });
    if (mode == _Mode.echo) {
      _echo.start();
      unawaited(_playEcho());
    }
  }

  /// Plays the song being learnt, at its own pace, the keys glowing as
  /// they play; then the lesson starts again from its first note.
  Future<void> _listenToSong() async {
    final lesson = _lesson;
    if (lesson == null) {
      return;
    }
    final generation = ++_generation;
    setState(() => _playingBack = true);
    var at = Duration.zero;
    for (final (time, _, midi) in lesson.melody.timeline()) {
      await Future<void>.delayed(time - at);
      at = time;
      if (!mounted || generation != _generation) {
        return;
      }
      if (pianoKeyFor(midi) case final key?) {
        unawaited(_press(key, replay: true));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted && generation == _generation) {
      setState(() {
        _playingBack = false;
        _missed = false;
        _lesson = PianoLesson(lesson.melody);
      });
    }
  }

  Future<void> _press(int index, {bool replay = false}) async {
    if (_mode == _Mode.echo && !replay) {
      return _echoPress(index);
    }
    if (_mode == _Mode.learn && _playingBack && !replay) {
      // Listening to the song first.
      return;
    }
    final playback = AppScope.of(context).playback;
    final key = pianoKeys[index];
    final recording = _recording;
    if (!replay && recording != null && _recorded.length < 400) {
      _recorded.add((recording.elapsed, index));
    }
    unawaited(HapticFeedback.selectionClick());
    unawaited(playback.note(key.midi, Instrument.musicBox));
    final lesson = replay ? null : _lesson;
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
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (mode, icon, label) in [
                      (_Mode.free, Icons.piano_outlined, l10n.pianoFree),
                      (_Mode.learn, Icons.school_outlined, l10n.pianoLearn),
                      (_Mode.echo, Icons.hearing_outlined, l10n.pianoEcho),
                    ])
                      ChoiceChip(
                        avatar: Icon(icon),
                        label: Text(label),
                        selected: _mode == mode,
                        onSelected: (_) => _setMode(mode),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_mode == _Mode.echo) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      switch (_echoing) {
                        _Echo.listen => l10n.pianoEchoListen,
                        _Echo.yourTurn => l10n.pianoEchoYourTurn,
                        _Echo.bravo => l10n.pianoEchoBravo,
                        _Echo.oops => l10n.pianoEchoOops,
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    [
                      l10n.pianoEchoNotes(_echo.keys.length),
                      if (preferences.pianoEchoBest > 0)
                        l10n.pianoEchoBest(preferences.pianoEchoBest),
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_mode == _Mode.free)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _playingBack ? null : _toggleRecording,
                        icon: Icon(
                          _recording == null
                              ? Icons.fiber_manual_record
                              : Icons.stop,
                          color: _recording == null ? Colors.red : null,
                        ),
                        label: Text(_recording == null
                            ? l10n.pianoRecord
                            : l10n.pianoStopRecording),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _recorded.isEmpty ||
                                _recording != null ||
                                _playingBack
                            ? null
                            : _playBack,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.pianoPlayBack),
                      ),
                      if (_recorded.isNotEmpty && _recording == null)
                        TextButton.icon(
                          onPressed: _playingBack ? null : _saveTune,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: Text(l10n.pianoSaveTune),
                        ),
                    ],
                  ),
                if (_mode == _Mode.free && preferences.myTunes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.pianoMyTunes,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  _ChipRow(
                    children: [
                      for (final tune in preferences.myTunes.reversed)
                        InputChip(
                          avatar: const Icon(Icons.music_note, size: 18),
                          label: Text(tune.name),
                          onPressed:
                              _playingBack ? null : () => _playBack(tune.notes),
                          onDeleted: () => _tuneMenu(tune),
                          deleteIcon: const Icon(Icons.more_vert, size: 18),
                          deleteButtonTooltipMessage: tune.name,
                        ),
                    ],
                  ),
                ],
                if (_mode == _Mode.free) const SizedBox(height: 12),
                if (lesson != null) ...[
                  // One row that scrolls sideways, so the keys keep the
                  // screen.
                  _ChipRow(
                    children: [
                      for (final song in pianoSongs)
                        ChoiceChip(
                          label: Text(MusicBoxScreen.nameOf(l10n, song)),
                          selected: lesson.melody.id == song.id,
                          onSelected: (_) => setState(() {
                            _generation++;
                            _playingBack = false;
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _playingBack ? null : _listenToSong,
                        icon: const Icon(Icons.hearing_outlined),
                        label: Text(l10n.pianoListenFirst),
                      ),
                      if (lesson.isFinished)
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _lesson = PianoLesson(lesson.melody)),
                          icon: const Icon(Icons.replay),
                          label: Text(l10n.gameAgain),
                        ),
                    ],
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
                              glowing: lesson?.next == i ||
                                  (_mode == _Mode.echo &&
                                      _echoing == _Echo.listen &&
                                      _pressed == i),
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

/// Chips in one row that scrolls sideways.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(right: 8), child: child),
          ],
        ),
      );
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

/// Asks for the name of a tune to keep.
class _TuneNameDialog extends StatefulWidget {
  const _TuneNameDialog({required this.initial});

  final String initial;

  @override
  State<_TuneNameDialog> createState() => _TuneNameDialogState();
}

class _TuneNameDialogState extends State<_TuneNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pianoTuneName),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: MyTune.maxName,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.pianoSaveTune),
        ),
      ],
    );
  }
}
