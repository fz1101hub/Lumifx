import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/speech/speaker.dart';
import '../../core/speech/voice_recordings.dart';
import '../common/app_text.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';
import 'playback_controller.dart';
import 'read_along.dart';

/// Reads a story's words aloud as they appear, in the app's language,
/// while it plays and the setting is on; quiet when paused or stopped.
/// Lines the user recorded in their own voice play instead, whether the
/// setting is on or not.
class ReadAloud {
  ReadAloud({
    required this.playback,
    required this.preferences,
    required this.library,
    required this.speaker,
    required this.locale,
    VoiceRecordings? voices,
    this.voicePlayer = const NoVoicePlayer(),
  }) : voices = voices ?? NoVoiceRecordings();

  final PlaybackController playback;
  final PreferencesController preferences;
  final EffectLibrary library;
  final Speaker speaker;
  final VoiceRecordings voices;
  final VoicePlayer voicePlayer;

  /// The app's language now.
  final Locale Function() locale;

  StreamSubscription<List<LightFrame>>? _frames;
  EffectPlayer? _player;
  LightingEffect? _effect;
  List<(int, String)> _lines = const [];
  int? _spoken;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    playback.addListener(_update);
    preferences.addListener(_update);
    _update();
  }

  void dispose() {
    playback.removeListener(_update);
    preferences.removeListener(_update);
    _quiet();
  }

  void _update() {
    final player = playback.player;
    final effect = playback.effect;
    final wanted = (preferences.readAloud || voices.hasAny(effect.id)) &&
        player != null &&
        playback.status == PlaybackStatus.playing;
    if (player == null) {
      // Stopped: played again, the story starts from its first words.
      _effect = null;
    }
    if (!wanted) {
      _quiet();
      return;
    }
    if (!identical(effect, _effect)) {
      // A new story starts from its first words, the last one's cut off
      // rather than queued before them.
      if (_spoken != null) {
        unawaited(speaker.stop());
        unawaited(voicePlayer.stop());
      }
      _effect = effect;
      _spoken = null;
      final l10n = lookupAppLocalizations(_supported(locale()));
      _lines = narrationOf(effect, l10n, library);
    }
    if (_lines.isEmpty) {
      _quiet();
      return;
    }
    if (identical(player, _player) && _frames != null) {
      return;
    }
    unawaited(_frames?.cancel());
    _player = player;
    _frames = player.frames.listen((_) => _onFrame(player));
    _onFrame(player);
  }

  void _onFrame(EffectPlayer player) {
    final effect = _effect;
    if (effect == null) {
      return;
    }
    final index = narrationIndexAt(effect, _lines, player.position);
    if (index == null || index == _spoken) {
      return;
    }
    _spoken = index;
    final (at, text) = _lines[index];
    final recorded = voices.pathOf(effect.id, at);
    if (recorded != null) {
      unawaited(voicePlayer.play(recorded));
    } else if (preferences.readAloud) {
      unawaited(speaker.speak(
        text,
        speechLanguage(_supported(locale()).languageCode),
        style: SpeechStyle.story,
      ));
    }
  }

  /// Stops speaking; the place in the story is kept for a resume.
  void _quiet() {
    final wasListening = _frames != null;
    unawaited(_frames?.cancel());
    _frames = null;
    _player = null;
    if (wasListening) {
      unawaited(speaker.stop());
      unawaited(voicePlayer.stop());
    }
  }

  static Locale _supported(Locale locale) =>
      AppLocalizations.supportedLocales
          .where((l) => l.languageCode == locale.languageCode)
          .firstOrNull ??
      const Locale('en');
}
