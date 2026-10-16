import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';

/// Siri's list of effects is generated (tool/gen_ios_intents.py): it must
/// follow the catalog, with every phrase and name in every language.
void main() {
  test('Siri knows every built-in effect', () {
    final swift = File('ios/Runner/LumiFXIntents.swift').readAsStringSync();
    for (final effect in effectCatalog) {
      expect(swift, contains('= "${effect.id}"'),
          reason:
              '${effect.id} is missing: run python3 tool/gen_ios_intents.py');
    }
  });

  test('the phrases and names are translated', () {
    const languages = ['it', 'de', 'fr', 'es', 'nl', 'pt-BR', 'ja'];
    final catalog =
        jsonDecode(File('ios/Runner/Localizable.xcstrings').readAsStringSync())
            as Map<String, Object?>;
    final strings = catalog['strings']! as Map<String, Object?>;
    expect(strings, isNotEmpty);
    for (final MapEntry(:key, :value) in strings.entries) {
      final localizations =
          (value! as Map<String, Object?>)['localizations']! as Map;
      expect(localizations.keys.toSet(), languages.toSet(), reason: key);
    }

    // Siri's phrases: one .strings file per language (a string catalog
    // would need iOS 17), each phrase naming the app.
    final line = RegExp(r'^"(.+)" = "(.+)";$');
    Map<String, String> phrases(String language) => {
          for (final l
              in File('ios/Runner/$language.lproj/AppShortcuts.strings')
                  .readAsLinesSync())
            if (line.firstMatch(l) case final m?) m[1]!: m[2]!,
        };
    final english = phrases('en');
    expect(english, hasLength(6));
    for (final language in languages) {
      final translated = phrases(language);
      expect(translated.keys.toSet(), english.keys.toSet(), reason: language);
      for (final MapEntry(:key, :value) in translated.entries) {
        expect(value, contains(r'${applicationName}'), reason: key);
        expect(value.contains(r'${effect}'), key.contains(r'${effect}'),
            reason: key);
      }
    }
  });
}
