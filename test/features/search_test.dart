import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/search/effect_search.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));
  final library =
      EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));

  test('accents and case do not matter', () {
    expect(foldForSearch('Noël À LA Plage'), 'noel a la plage');
  });

  test('finds by name, description and collection, in the app language', () {
    expect(searchEffects(en, library, 'aurora').map((e) => e.id), ['aurora']);
    expect(
      searchEffects(en, library, 'dragon').map((e) => e.id),
      contains('sleeping_dragon'),
    );
    final halloween = searchEffects(en, library, 'halloween');
    expect(halloween.length, greaterThanOrEqualTo(4));
    // Every word has to match.
    expect(searchEffects(en, library, 'pumpkin castle'), isEmpty);
    // French names: "Feu de cheminée" or similar for Fireplace.
    final fireplace = searchEffects(fr, library, fr.effectNameFireplace);
    expect(fireplace.map((e) => e.id), contains('fireplace'));
  });

  test('narrows by kind and collection', () {
    final scenes = searchEffects(en, library, '', kind: EffectKind.scene);
    expect(scenes.every((e) => e.kind == EffectKind.scene), isTrue);
    final relax = searchEffects(en, library, '', collection: 'Relax');
    expect(relax.map((e) => e.id), containsAll(['fireplace', 'sunset']));
    expect(relax.map((e) => e.id), isNot(contains('ocean')));
  });

  test('the user scenes are found too', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.saveUserScene(const UserScene(
      id: 'user:1',
      name: 'Reading corner',
      colors: ['#FFAA00', '#FFFFFF'],
    ));
    final mine = EffectLibrary(preferences);
    expect(searchEffects(en, mine, 'reading').single.id, 'user:1');
    expect(searchEffects(en, mine, '', collection: 'My scenes').single.id,
        'user:1');
  });
}
