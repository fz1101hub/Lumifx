import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/entertainment/dtls/dtls_client.dart';
import 'package:lumifx/src/core/hue/hue_exceptions.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';

void main() {
  final it = lookupAppLocalizations(const Locale('it'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('every built-in effect has a translated name and description', () {
    for (final effect in effectCatalog) {
      expect(it.effectName(effect), isNotEmpty, reason: effect.id);
      expect(it.effectDescription(effect), isNot(effect.description),
          reason: '${effect.id} description is untranslated');
      expect(en.effectName(effect), effect.name);
      expect(en.effectDescription(effect), effect.description);
      if (effect.collection != null) {
        expect(it.collectionName(effect), isNotEmpty);
      }
      for (final variant in effect.variants) {
        // "Neon" is the same word in Italian: only check it is mapped.
        expect(it.variantName(variant), isNotEmpty, reason: variant.id);
        expect(en.variantName(variant), variant.name);
      }
    }
    expect(it.variantClassic, isNotEmpty);
  });

  test('errors the app knows are translated, others keep their words', () {
    expect(describeError(it, const UnsupportedBridgeException()),
        contains('aggiornamento'));
    expect(
      describeError(
          it, const DtlsException('x', failure: DtlsFailure.keyRejected)),
      contains('chiave di streaming'),
    );
    expect(
        describeError(it, const SocketException('down')), it.errorNoResponse);
    expect(describeError(it, const HueException('Bridge says no')),
        'Bridge says no');
    expect(describeError(it, StateError('?')), it.errorGeneric);
  });

  test('every supported locale is wired up', () {
    final expected = {
      'en': 'Play',
      'it': 'Riproduci',
      'de': 'Abspielen',
      'fr': 'Lecture',
      'es': 'Reproducir',
      'nl': 'Afspelen',
    };
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      expected.keys.toSet(),
    );
    for (final MapEntry(key: code, value: play) in expected.entries) {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.play, play, reason: code);
      expect(l10n.lightCount(2), isNot(contains('{')), reason: code);
      expect(l10n.effectName(effectCatalog.first), isNotEmpty, reason: code);
    }
  });

  test('playback notices and bridge problems have Italian text', () {
    expect(
      describePlaybackNotice(
        it,
        const PlaybackNotice(PlaybackNoticeKind.onOffOnlyLights,
            name: 'Cucina'),
      ),
      contains('Cucina'),
    );
    expect(
      describePlaybackNotice(
        it,
        const PlaybackNotice(PlaybackNoticeKind.streamEnded,
            error: EntertainmentStoppedException()),
      ),
      it.errorStreamTakenOver,
    );
    expect(
      describePlaybackNotice(
        it,
        const PlaybackNotice(PlaybackNoticeKind.bridgeUnreachable,
            problem: BridgeProblem.unauthorized),
      ),
      it.bridgeProblemUnauthorized,
    );
    for (final problem in BridgeProblem.values) {
      expect(describeBridgeProblem(it, problem), isNotEmpty);
    }
    expect(describeSlot(it, const PreviewLamp(2)), 'Lampada 2');
    expect(it.lightCount(1), '1 luce');
    expect(it.lightCount(3), '3 luci');
  });
}
