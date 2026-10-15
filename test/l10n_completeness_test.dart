import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every translation file must carry every key of the template, with the
/// same placeholders, so no locale silently falls back to English.
void main() {
  final files = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final template = files.singleWhere((f) => f.path.endsWith('app_en.arb'));
  final english = _messages(template);
  final placeholder = RegExp(r'\{([a-zA-Z]+)[,}]');

  test('there is a template and at least one translation', () {
    expect(english, isNotEmpty);
    expect(files.length, greaterThan(1));
  });

  for (final file in files) {
    test('${file.uri.pathSegments.last} is complete', () {
      final messages = _messages(file);
      expect(messages.keys.toSet(), english.keys.toSet(),
          reason: 'keys differ from the template');
      for (final MapEntry(:key, :value) in messages.entries) {
        expect(value.trim(), isNotEmpty, reason: '$key is empty');
        final expected =
            placeholder.allMatches(english[key]!).map((m) => m[1]).toSet();
        final actual = placeholder.allMatches(value).map((m) => m[1]).toSet();
        expect(actual, expected, reason: '$key placeholders differ');
      }
    });
  }
}

Map<String, String> _messages(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}
