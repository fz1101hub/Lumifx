import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud with the phone's own voice.
abstract interface class Speaker {
  /// Queues [text] in [language] (a BCP 47 tag such as `it-IT`).
  Future<void> speak(String text, String language);

  /// Stops speaking and drops what is queued.
  Future<void> stop();
}

class NoSpeaker implements Speaker {
  const NoSpeaker();

  @override
  Future<void> speak(String text, String language) async {}

  @override
  Future<void> stop() async {}
}

/// The system's text-to-speech, a little slower than usual for children,
/// lines queued one after the other, mixing with other sound.
class TtsSpeaker implements Speaker {
  TtsSpeaker();

  final _tts = FlutterTts();
  Future<void>? _setUp;
  String? _language;

  Future<void> _ready() => _setUp ??= () async {
        await _tts.setSpeechRate(0.45);
        if (Platform.isAndroid) {
          await _tts.setQueueMode(1);
        }
        if (Platform.isIOS) {
          await _tts.setSharedInstance(true);
          await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          );
        }
      }();

  @override
  Future<void> speak(String text, String language) async {
    try {
      await _ready();
      if (_language != language) {
        _language = language;
        await _tts.setLanguage(language);
      }
      await _tts.speak(text);
    } on Object catch (error) {
      debugPrint('Speech: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Nothing was speaking.
    }
  }
}

/// The voice language for the app's [languageCode].
String speechLanguage(String languageCode) => switch (languageCode) {
      'it' => 'it-IT',
      'de' => 'de-DE',
      'fr' => 'fr-FR',
      'es' => 'es-ES',
      'nl' => 'nl-NL',
      'pt' => 'pt-BR',
      'ja' => 'ja-JP',
      _ => 'en-US',
    };
