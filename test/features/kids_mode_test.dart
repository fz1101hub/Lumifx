import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/kids/kids_mode.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  test('kids get no flashes, no microphone, no camera', () {
    for (final effect in effectCatalog) {
      if (kidsSafe(effect)) {
        expect(effect.hasRapidFlashes, isFalse, reason: effect.id);
        expect(effect.kind, isNot(EffectKind.interactive), reason: effect.id);
      }
    }
    expect(effectCatalog.where(kidsSafe), isNotEmpty);
    expect(
        effectCatalog.where((e) => e.hasRapidFlashes).where(kidsSafe), isEmpty);
  });

  test('before a grown-up chooses: up to eight gentle effects', () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    final ids = defaultKidsEffects(library);
    expect(ids, hasLength(8));
    for (final id in ids) {
      expect(kidsSafe(library.byId(id)!), isTrue);
    }
  });

  test('locked, only the chosen gentle effects may start', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final library = EffectLibrary(preferences);
    final ocean = library.byId('ocean')!;
    final storm = library.byId('thunderstorm')!;
    expect(kidsModeAllows(preferences, library, storm), isTrue,
        reason: 'not in kids mode');
    await preferences.setKidsLocked(true);
    expect(kidsModeAllows(preferences, library, storm), isFalse);
    expect(kidsModeAllows(preferences, library, ocean),
        defaultKidsEffects(library).contains('ocean'));
    await preferences.setKidsEffects(['ocean', 'thunderstorm']);
    expect(kidsModeAllows(preferences, library, ocean), isTrue);
    expect(kidsModeAllows(preferences, library, storm), isFalse,
        reason: 'flashing effects never, even if listed');
  });

  test('the choice and the lock are kept', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    expect(preferences.kidsEffects, isNull);
    expect(preferences.kidsLocked, isFalse);
    await preferences.setKidsEffects(['ocean', 'sleeping_dragon']);
    await preferences.setKidsLocked(true);
    final again = PreferencesController(store: store);
    await again.load();
    expect(again.kidsEffects, ['ocean', 'sleeping_dragon']);
    expect(again.kidsLocked, isTrue);
  });
}
