import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  test('the stars from before profiles become the first child\'s', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    expect(preferences.earnStar('2026-10-17:morning'), isTrue);
    final anna = await preferences.addChild('Anna');
    expect(anna, '');
    expect(preferences.activeChild?.name, 'Anna');
    expect(preferences.stars, {'2026-10-17:morning'});
  });

  test('each child has their own stars, steps and spent stars', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    final anna = await preferences.addChild('Anna');
    await preferences.setRoutineSteps('evening', ['bath']);
    expect(preferences.earnStar('2026-10-18:evening'), isTrue);
    final leo = await preferences.addChild('  Leo ');
    expect(preferences.activeChildId, leo);
    expect(preferences.stars, isEmpty);
    expect(preferences.routineSteps('evening'), isNull);
    expect(preferences.earnStar('2026-10-18:evening'), isTrue,
        reason: 'Leo earns his own star the same day');
    expect(preferences.earnStar('2026-10-18:morning'), isTrue);
    expect(preferences.starsOf(anna), {'2026-10-18:evening'});
    expect(preferences.starsOf(leo), hasLength(2));

    expect(preferences.spendStars(leo, 3), isFalse);
    expect(preferences.spendStars(leo, 2), isTrue);
    expect(preferences.starBalance(leo), 0);
    expect(preferences.starBalance(anna), 1);

    final again = PreferencesController(store: store);
    await again.load();
    expect([for (final c in again.children) c.name], ['Anna', 'Leo']);
    expect(again.activeChildId, leo);
    expect(again.starBalance(leo), 0);
    expect(again.routineSteps('evening', child: anna), ['bath']);

    await again.removeChild(leo);
    expect(again.activeChildId, anna);
    expect(again.starsOf(leo), isEmpty);
    expect(again.starsOf(anna), {'2026-10-18:evening'});
    expect(again.starsSpent(leo), 0);
  });

  test('names are trimmed, and the family has room for six', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.addChild('   ');
    expect(preferences.children, isEmpty);
    for (var i = 0; i < 8; i++) {
      await preferences.addChild('Child $i');
    }
    expect(preferences.children, hasLength(6));
    await preferences.renameChild(preferences.children.first.id, 'Mia');
    expect(preferences.children.first.name, 'Mia');
  });

  test('rewards are kept, checked and removed', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    await preferences.addReward('  Ice cream ', 5, 0);
    await preferences.addReward('', 3, 0);
    await preferences.addReward('Park', 0, 3);
    await preferences.addReward('Film', 8, 99);
    expect(
        [for (final r in preferences.rewards) r.name], ['Ice cream', 'Film']);
    expect(preferences.rewards.last.icon, 0, reason: 'unknown picture');
    final again = PreferencesController(store: store);
    await again.load();
    expect(again.rewards.first.cost, 5);
    await again.removeReward(again.rewards.first.id);
    expect([for (final r in again.rewards) r.name], ['Film']);
  });
}
