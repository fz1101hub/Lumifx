import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../music_box/light_piano.dart';
import 'sing_colour.dart';

/// Sing and colour: the microphone hears how high and loud the voice is,
/// and the lamps take the note's colour at once, brighter the longer it
/// is held. It listens only while this screen is open and in front.
class SingColourScreen extends StatefulWidget {
  const SingColourScreen({super.key});

  @override
  State<SingColourScreen> createState() => _SingColourScreenState();
}

class _SingColourScreenState extends State<SingColourScreen>
    with WidgetsBindingObserver {
  late AudioInput _microphone;
  StreamSubscription<Uint8List>? _listening;
  SungColour? _sung;
  var _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _microphone = AppScope.of(context).audioInput;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _listening != null) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final listening = _listening;
    _listening = null;
    if (listening != null) {
      unawaited(listening.cancel());
      unawaited(_microphone.stop());
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final playback = AppScope.of(context).playback;
    setState(() => _starting = true);
    try {
      if (!await _microphone.requestPermission()) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.singMicDenied)));
        return;
      }
      if (!mounted) {
        return;
      }
      playback.setSleepTimer(null);
      await playback.switchEffect(PitchWatch.background(l10n.sing));
      if (playback.status == PlaybackStatus.idle) {
        await playback.start();
      } else if (playback.status == PlaybackStatus.paused) {
        await playback.resume();
      }
      final watch = PitchWatch(sampleRate: _microphone.sampleRate);
      final audio = await _microphone.start();
      if (!mounted) {
        await _microphone.stop();
        return;
      }
      setState(() {
        _listening = audio.listen((pcm) {
          final sung = watch.add(pcm);
          if (sung != null) {
            // At once: each reading refreshes the colour over the night
            // blue, so the lamps follow the voice note by note.
            playback.flash(sung.color,
                brightness: sung.brightness,
                length: const Duration(milliseconds: 900));
          }
          if (mounted && (sung != null) != (_sung != null) ||
              (sung != null && (sung.midi - (_sung?.midi ?? 0)).abs() > 0.5)) {
            setState(() => _sung = sung);
          }
        }, onError: (Object error) {
          debugPrint('Sing microphone: $error');
          unawaited(_stop());
        }, onDone: () => unawaited(_stop()));
      });
    } on Object catch (error) {
      debugPrint('Sing microphone: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.singMicDenied)));
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _stop() async {
    final listening = _listening;
    _listening = null;
    _sung = null;
    if (listening != null) {
      unawaited(listening.cancel());
      await _microphone.stop();
    }
    if (!mounted) {
      return;
    }
    final playback = AppScope.of(context).playback;
    if (PitchWatch.isSinging(playback.effect)) {
      unawaited(playback.stop());
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sung = _sung;
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sing)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.singDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          if (_listening != null) ...[
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sung == null
                      ? Colors.black
                      : sung.color
                          .toColor()
                          .withValues(alpha: 0.4 + 0.6 * sung.brightness),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  sung == null ? '' : _noteName(sung.midi, language),
                  style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                sung == null ? l10n.singListening : l10n.singHold,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: Text(l10n.stop),
              ),
            ),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _starting ? null : _start,
              icon: const Icon(Icons.mic_none),
              label: Text(l10n.singStart),
            ),
        ],
      ),
    );
  }

  /// The note sung, by the names the light piano uses (do re mi, or C D
  /// E), for the nearest white key.
  static String _noteName(double midi, String language) {
    const whites = [0, 2, 4, 5, 7, 9, 11];
    final pitch = midi.round() % 12;
    var best = 0;
    for (var i = 0; i < whites.length; i++) {
      if ((whites[i] - pitch).abs() < (whites[best] - pitch).abs()) {
        best = i;
      }
    }
    return pianoNoteName(language, best);
  }
}
