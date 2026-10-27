import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// How a voice sounds, as the phone reports it.
enum VoiceQuality {
  /// Robotic or a joke voice (iPhone's Bells, Zarvox, Eloquence...).
  novelty,

  /// The small voice phones come with.
  basic,

  /// A downloaded, more natural voice (iPhone "Enhanced", Android high).
  enhanced,

  /// The most natural (iPhone "Premium", Android very high).
  premium,
}

/// A voice the phone can read with.
@immutable
class SpeechVoice {
  const SpeechVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.quality = VoiceQuality.basic,
    this.needsNetwork = false,
  });

  /// What [Speaker] needs to pick it again: the iPhone's identifier, the
  /// Android voice's name.
  final String id;
  final String name;

  /// A BCP 47 tag, as the platform spells it (`it-IT`).
  final String locale;
  final VoiceQuality quality;

  /// Android voices that are synthesised online.
  final bool needsNetwork;

  /// From one of `flutter_tts`'s `getVoices` maps; null for a voice that
  /// cannot speak right now (not downloaded, the user's Personal Voice).
  static SpeechVoice? fromPlatform(Map<Object?, Object?> map) {
    final name = map['name'];
    final locale = map['locale'];
    if (name is! String || locale is! String || name.isEmpty) {
      return null;
    }
    final identifier = map['identifier'];
    final features = '${map['features'] ?? ''}'.split('\t');
    if (features.contains('notInstalled')) {
      return null;
    }
    if (identifier is String && identifier.isNotEmpty) {
      // iPhone.
      if (identifier.contains('personalvoice')) {
        return null;
      }
      final novelty = identifier.contains('speech.synthesis.voice') ||
          identifier.contains('eloquence');
      return SpeechVoice(
        id: identifier,
        name: name,
        locale: locale,
        quality: novelty
            ? VoiceQuality.novelty
            : switch (map['quality']) {
                'premium' => VoiceQuality.premium,
                'enhanced' => VoiceQuality.enhanced,
                _ => VoiceQuality.basic,
              },
      );
    }
    return SpeechVoice(
      id: name,
      name: name,
      locale: locale,
      quality: switch (map['quality']) {
        'very high' => VoiceQuality.premium,
        'high' => VoiceQuality.enhanced,
        'low' || 'very low' => VoiceQuality.novelty,
        _ => VoiceQuality.basic,
      },
      needsNetwork: map['network_required'] == '1',
    );
  }

  /// The map `flutter_tts`'s `setVoice` looks for.
  Map<String, String> toPlatform() => {
        'name': name,
        'locale': locale,
        if (id != name) 'identifier': id,
      };

  @override
  bool operator ==(Object other) =>
      other is SpeechVoice &&
      other.id == id &&
      other.locale == locale &&
      other.quality == quality &&
      other.needsNetwork == needsNetwork;

  @override
  int get hashCode => Object.hash(id, locale, quality, needsNetwork);
}

/// The voices of [all] for [language] (`pt-BR`), best first: the most
/// natural, offline ones before those that need the internet at the same
/// quality. Joke voices only when there is nothing else; another country's
/// voices of the same language (`pt-PT`) only when there is none for it.
List<SpeechVoice> voicesFor(List<SpeechVoice> all, String language) {
  String norm(String tag) => tag.replaceAll('_', '-').toLowerCase();
  final wanted = norm(language);
  final base = wanted.split('-').first;
  var matching = [
    for (final v in all)
      if (norm(v.locale) == wanted) v,
  ];
  if (matching.isEmpty) {
    matching = [
      for (final v in all)
        if (norm(v.locale).split('-').first == base) v,
    ];
  }
  final real = [
    for (final v in matching)
      if (v.quality != VoiceQuality.novelty) v,
  ];
  final list = real.isEmpty ? matching : real;
  // A stable sort: the platform's own order among equals.
  return [
    for (final (_, v) in (list.indexed.toList()
      ..sort((a, b) {
        final quality = b.$2.quality.index.compareTo(a.$2.quality.index);
        if (quality != 0) {
          return quality;
        }
        final network =
            (a.$2.needsNetwork ? 1 : 0).compareTo(b.$2.needsNetwork ? 1 : 0);
        return network != 0 ? network : a.$1.compareTo(b.$1);
      })))
      v,
  ];
}

/// The voice read with when none was chosen: the best one that works
/// without the internet (bedtime may well be offline), else the best.
SpeechVoice? bestVoice(List<SpeechVoice> voices) =>
    voices.where((v) => !v.needsNetwork).firstOrNull ?? voices.firstOrNull;

/// What is being read.
enum SpeechStyle {
  /// A word or a short call in a game: a little slower than usual.
  call,

  /// A story: slower, a touch warmer, a breath between sentences.
  story,
}

/// [text] cut after each sentence, so each is its own utterance and the
/// voice pauses between them as a storyteller does.
List<String> sentencesOf(String text) => [
      for (final match
          in RegExp(r'[^.!?…。！？]+(?:[.!?…。！？]+["»”’)]*|$)').allMatches(text))
        if (match[0]!.trim() case final sentence when sentence.isNotEmpty)
          sentence,
    ];

/// Reads text aloud with the phone's own voice.
abstract interface class Speaker {
  /// Queues [text] in [language] (a BCP 47 tag such as `it-IT`).
  Future<void> speak(
    String text,
    String language, {
    SpeechStyle style = SpeechStyle.call,
  });

  /// Stops speaking and drops what is queued.
  Future<void> stop();

  /// The voices the phone has for [language], best first (see
  /// [voicesFor]); looked up again each time, as voices can be downloaded
  /// while the app runs.
  Future<List<SpeechVoice>> voices(String language);
}

class NoSpeaker implements Speaker {
  const NoSpeaker();

  @override
  Future<void> speak(
    String text,
    String language, {
    SpeechStyle style = SpeechStyle.call,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<SpeechVoice>> voices(String language) async => const [];
}

/// The system's text-to-speech with the voice chosen in Settings, else
/// the most natural one the phone has; a little slower than usual for
/// children, slower still for stories. Lines are queued one after the
/// other, mixing with other sound.
class TtsSpeaker implements Speaker {
  TtsSpeaker({this.voiceFor});

  /// The id of the voice chosen for a language, if any.
  final String? Function(String language)? voiceFor;

  final _tts = FlutterTts();
  Future<void>? _setUp;
  Future<List<SpeechVoice>>? _all;
  String? _language;
  SpeechVoice? _voice;
  SpeechStyle? _style;

  /// Moves on at [stop]: sentences of a story not yet queued then stay
  /// unsaid.
  var _generation = 0;

  static const _rate = {SpeechStyle.call: 0.45, SpeechStyle.story: 0.42};
  static const _pitch = {SpeechStyle.call: 1.0, SpeechStyle.story: 1.05};

  Future<void> _ready() => _setUp ??= () async {
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

  Future<List<SpeechVoice>> _allVoices({bool fresh = false}) {
    if (fresh) {
      _all = null;
    }
    return _all ??= () async {
      final raw = await _tts.getVoices;
      return [
        if (raw is List)
          for (final map in raw.whereType<Map<Object?, Object?>>())
            if (SpeechVoice.fromPlatform(map) case final voice?) voice,
      ];
    }()
        .catchError((Object error) {
      _all = null;
      debugPrint('Speech voices: $error');
      return <SpeechVoice>[];
    });
  }

  @override
  Future<List<SpeechVoice>> voices(String language) async =>
      voicesFor(await _allVoices(fresh: true), language);

  /// The chosen voice if the phone still has it, else the best.
  Future<SpeechVoice?> _voiceFor(String language) async {
    final voices = voicesFor(await _allVoices(), language);
    final chosen = voiceFor?.call(language);
    return voices.where((v) => v.id == chosen).firstOrNull ?? bestVoice(voices);
  }

  @override
  Future<void> speak(
    String text,
    String language, {
    SpeechStyle style = SpeechStyle.call,
  }) async {
    final generation = _generation;
    try {
      await _ready();
      final voice = await _voiceFor(language);
      if (_language != language || _voice != voice) {
        _language = language;
        _voice = voice;
        // On iPhone the language clears the voice: the voice comes after.
        await _tts.setLanguage(language);
        if (voice != null) {
          await _tts.setVoice(voice.toPlatform());
        }
      }
      if (_style != style) {
        _style = style;
        await _tts.setSpeechRate(_rate[style]!);
        await _tts.setPitch(_pitch[style]!);
      }
      for (final part
          in style == SpeechStyle.story ? sentencesOf(text) : [text]) {
        if (generation != _generation) {
          return;
        }
        await _tts.speak(part);
      }
    } on Object catch (error) {
      debugPrint('Speech: $error');
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
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
