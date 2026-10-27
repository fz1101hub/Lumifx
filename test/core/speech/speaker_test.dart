import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/speech/speaker.dart';

/// What the iPhone and Android plugins report, trimmed to what matters.
final _iphone = <Map<String, String>>[
  {
    'name': 'Alice',
    'locale': 'it-IT',
    'quality': 'default',
    'identifier': 'com.apple.voice.compact.it-IT.Alice',
  },
  {
    'name': 'Federica',
    'locale': 'it-IT',
    'quality': 'premium',
    'identifier': 'com.apple.voice.premium.it-IT.Federica',
  },
  {
    'name': 'Luca',
    'locale': 'it-IT',
    'quality': 'enhanced',
    'identifier': 'com.apple.voice.enhanced.it-IT.Luca',
  },
  {
    'name': 'Nonna',
    'locale': 'it-IT',
    'quality': 'default',
    'identifier': 'com.apple.eloquence.it-IT.Grandma',
  },
  {
    'name': 'Bells',
    'locale': 'en-US',
    'quality': 'default',
    'identifier': 'com.apple.speech.synthesis.voice.Bells',
  },
  {
    'name': 'Me',
    'locale': 'it-IT',
    'quality': 'enhanced',
    'identifier': 'com.apple.speech.personalvoice.abc',
  },
];

final _android = <Map<String, String>>[
  {
    'name': 'it-it-x-kda-network',
    'locale': 'it-IT',
    'quality': 'very high',
    'network_required': '1',
    'features': 'networkTimeoutMs\tnetworkRetriesCount',
  },
  {
    'name': 'it-it-x-kdb-local',
    'locale': 'it-IT',
    'quality': 'high',
    'network_required': '0',
    'features': '',
  },
  {
    'name': 'it-it-x-itd-local',
    'locale': 'it-IT',
    'quality': 'very high',
    'network_required': '0',
    'features': 'notInstalled',
  },
  {
    'name': 'pt-pt-x-jfb-local',
    'locale': 'pt-PT',
    'quality': 'high',
    'network_required': '0',
  },
];

List<SpeechVoice> _parse(List<Map<String, String>> maps) => [
      for (final map in maps)
        if (SpeechVoice.fromPlatform(map) case final voice?) voice,
    ];

void main() {
  group('the phone\'s voices', () {
    test('iPhone voices: quality, joke voices, never a Personal Voice', () {
      final voices = _parse(_iphone);
      expect(voices.map((v) => v.name), isNot(contains('Me')));
      final byName = {for (final v in voices) v.name: v};
      expect(byName['Federica']!.quality, VoiceQuality.premium);
      expect(byName['Luca']!.quality, VoiceQuality.enhanced);
      expect(byName['Alice']!.quality, VoiceQuality.basic);
      expect(byName['Nonna']!.quality, VoiceQuality.novelty);
      expect(byName['Bells']!.quality, VoiceQuality.novelty);
      expect(byName['Luca']!.toPlatform(), {
        'name': 'Luca',
        'locale': 'it-IT',
        'identifier': 'com.apple.voice.enhanced.it-IT.Luca',
      });
    });

    test('Android voices: quality, online ones, not downloaded ones left out',
        () {
      final voices = _parse(_android);
      expect(voices.map((v) => v.id), isNot(contains('it-it-x-itd-local')));
      final network = voices.firstWhere((v) => v.id.endsWith('network'));
      expect(network.quality, VoiceQuality.premium);
      expect(network.needsNetwork, isTrue);
      expect(network.toPlatform(),
          {'name': 'it-it-x-kda-network', 'locale': 'it-IT'});
    });

    test('best first, joke voices only when there is nothing else', () {
      final italian = voicesFor(_parse(_iphone), 'it-IT');
      expect(italian.map((v) => v.name), ['Federica', 'Luca', 'Alice']);
      expect(bestVoice(italian)!.name, 'Federica');
      // English has only Bells here: better than nothing.
      expect(voicesFor(_parse(_iphone), 'en-US').map((v) => v.name), ['Bells']);
    });

    test('a voice that works offline is the automatic choice', () {
      final italian = voicesFor(_parse(_android), 'it-IT');
      expect(italian.first.needsNetwork, isTrue, reason: 'listed first');
      expect(bestVoice(italian)!.id, 'it-it-x-kdb-local');
    });

    test('another country\'s voice only when there is none for this one', () {
      final voices = _parse(_android);
      expect(voicesFor(voices, 'pt-BR').single.id, 'pt-pt-x-jfb-local');
      expect(voicesFor(voices, 'it_it'), hasLength(2));
      expect(voicesFor(voices, 'ja-JP'), isEmpty);
      expect(bestVoice(const []), isNull);
    });
  });

  test('a story is read a sentence at a time', () {
    expect(
      sentencesOf('Once upon a time… a lamp woke up! "Who is there?" '
          'Nobody answered'),
      [
        'Once upon a time…',
        'a lamp woke up!',
        '"Who is there?"',
        'Nobody answered'
      ],
    );
    expect(sentencesOf('むかしむかし。ランプがひかりました！'), ['むかしむかし。', 'ランプがひかりました！']);
    expect(sentencesOf('  '), isEmpty);
  });

  group('TtsSpeaker', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('flutter_tts');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'getVoices' ? _iphone : 1;
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    List<String> said() => [
          for (final c in calls)
            if (c.method == 'speak') c.arguments as String,
        ];

    test('reads with the best voice, a story slower and a sentence at a time',
        () async {
      final speaker = TtsSpeaker();
      await speaker.speak('C\'era una volta. Una lampada!', 'it-IT',
          style: SpeechStyle.story);
      final voice = calls.firstWhere((c) => c.method == 'setVoice');
      expect((voice.arguments as Map)['name'], 'Federica');
      expect(calls.indexWhere((c) => c.method == 'setLanguage'),
          lessThan(calls.indexOf(voice)),
          reason: 'the language would clear the voice on an iPhone');
      expect(
          calls.firstWhere((c) => c.method == 'setSpeechRate').arguments, 0.42);
      expect(said(), ['C\'era una volta.', 'Una lampada!']);

      // A game call: one utterance, the usual pace, the voice kept.
      calls.clear();
      await speaker.speak('Rosso. Blu.', 'it-IT');
      expect(said(), ['Rosso. Blu.']);
      expect(calls.where((c) => c.method == 'setVoice'), isEmpty);
      expect(
          calls.firstWhere((c) => c.method == 'setSpeechRate').arguments, 0.45);
    });

    test('the voice chosen in Settings, while the phone still has it',
        () async {
      String? chosen = 'com.apple.voice.enhanced.it-IT.Luca';
      final speaker = TtsSpeaker(voiceFor: (_) => chosen);
      await speaker.speak('Ciao', 'it-IT');
      expect(
          (calls.lastWhere((c) => c.method == 'setVoice').arguments
              as Map)['name'],
          'Luca');

      chosen = 'com.apple.voice.gone';
      await speaker.speak('Ciao', 'it-IT');
      expect(
          (calls.lastWhere((c) => c.method == 'setVoice').arguments
              as Map)['name'],
          'Federica');
    });

    test('stopped, the rest of the story is not queued', () async {
      final speaker = TtsSpeaker();
      final speaking =
          speaker.speak('Uno. Due. Tre.', 'it-IT', style: SpeechStyle.story);
      await speaker.stop();
      await speaking;
      expect(said(), isEmpty);
    });
  });
}
