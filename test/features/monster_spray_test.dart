import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/bedtime/monster_spray.dart';

void main() {
  test('each puff chases one monster, until none are left', () {
    final hunt = MonsterHunt(count: 3);
    expect(hunt.left, 3);
    expect(hunt.spray(), 2);
    expect(hunt.spray(), 1);
    expect(hunt.isDone, isFalse);
    expect(hunt.spray(), 0);
    expect(hunt.isDone, isTrue);
    expect(hunt.spray(), 0);
  });

  test('the hiding monsters and the guardian light are gentle', () {
    final hiding = MonsterHunt.hiding('Monster spray');
    final guardian = MonsterHunt.guardian('Guardian light');
    expect(MonsterHunt.isHunting(hiding), isTrue);
    expect(MonsterHunt.isGuardian(hiding), isFalse);
    expect(MonsterHunt.isGuardian(guardian), isTrue);
    for (final effect in [hiding, guardian]) {
      expect(effect.isGenerated, isTrue);
      expect(effect.hasRapidFlashes, isFalse);
      expect(effect.isLooping, isTrue);
    }
  });
}
