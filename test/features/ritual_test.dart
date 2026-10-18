import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/bedtime/ritual.dart';

void main() {
  test('the ritual settings survive a round trip, in the ritual order', () {
    final settings = const RitualSettings()
        .withStep(RitualStep.routine, false)
        .copyWith(lullaby: 'twinkle', guardianMinutes: 60);
    final back = RitualSettings.fromJson(settings.toJson());
    expect(back.steps, [
      RitualStep.monsterSpray,
      RitualStep.story,
      RitualStep.lullaby,
      RitualStep.guardian,
    ]);
    expect(back.lullaby, 'twinkle');
    expect(back.guardianMinutes, 60);
    expect(
        RitualSettings.fromJson({
          'steps': ['guardian', 'story'],
        }).steps,
        [RitualStep.story, RitualStep.guardian]);
  });

  test('a ritual keeps at least one step; odd values fall back', () {
    var settings = const RitualSettings(steps: [RitualStep.story]);
    settings = settings.withStep(RitualStep.story, false);
    expect(settings.steps, [RitualStep.story]);
    final odd = RitualSettings.fromJson({
      'steps': ['nap'],
      'lullaby': 'rock',
      'guardianMinutes': 7
    });
    expect(odd.steps, RitualStep.values);
    expect(odd.lullaby, 'brahms');
    expect(odd.guardianMinutes, 30);
  });
}
