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
    for (final file in ['AppShortcuts', 'Localizable']) {
      final catalog =
          jsonDecode(File('ios/Runner/$file.xcstrings').readAsStringSync())
              as Map<String, Object?>;
      final strings = catalog['strings']! as Map<String, Object?>;
      expect(strings, isNotEmpty);
      for (final MapEntry(:key, :value) in strings.entries) {
        final localizations =
            (value! as Map<String, Object?>)['localizations']! as Map;
        expect(localizations.keys.toSet(), languages.toSet(), reason: key);
        if (file == 'AppShortcuts') {
          for (final l in localizations.values) {
            final text = ((l as Map)['stringUnit'] as Map)['value'] as String;
            expect(text, contains(r'${applicationName}'), reason: key);
            expect(text.contains(r'${effect}'), key.contains(r'${effect}'),
                reason: key);
          }
        }
      }
    }
  });
}
