import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';

void main() {
  test('a scene of your own plays as an ambient palette', () {
    const scene = UserScene(
      id: 'user:1',
      name: 'Embers',
      colors: ['#FF0000', '#FFAA00'],
      motion: SceneMotion.flicker,
    );
    final effect = scene.toEffect();
    expect(effect.kind, EffectKind.scene);
    expect(effect.name, 'Embers');
    final parameters = effect.events.single.parameters;
    expect(parameters['palette'], ['#FF0000', '#FFAA00']);
    expect(parameters['flicker'], greaterThan(0));
    expect(effect.hasRapidFlashes, isFalse);
    final frames =
        EffectRenderer(effect, slotCount: 3).render(const Duration(seconds: 7));
    for (final frame in frames) {
      expect(frame.brightness, inInclusiveRange(0.0, 1.0));
      expect(frame.color.b, lessThan(0.05), reason: 'only reds and oranges');
    }
  });

  test('stored scenes are checked when they are read back', () {
    expect(
        UserScene.fromJson({'id': 'ocean', 'name': 'x', 'colors': []}), isNull,
        reason: 'ids of built-in effects are refused');
    expect(
      UserScene.fromJson({
        'id': 'user:2',
        'name': 'One colour',
        'colors': ['#FF0000', 'red'],
      }),
      isNull,
      reason: 'fewer than two valid colours',
    );
    final scene = UserScene.fromJson({
      'id': 'user:3',
      'name': 'Many',
      'colors': ['#000001', '#000002', '#000003', '#000004', '#000005', '#6'],
      'motion': 'disco',
    })!;
    expect(scene.colors, hasLength(5));
    expect(scene.motion, SceneMotion.drift, reason: 'unknown motion');
  });

  test('the library puts the user scenes first and finds them by id', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final library = EffectLibrary(preferences);
    expect(library.userScenes, isEmpty);
    await preferences.saveUserScene(const UserScene(
      id: 'user:a',
      name: 'A',
      colors: ['#FF0000', '#00FF00'],
    ));
    final scenes = library.ofKind(EffectKind.scene);
    expect(scenes.first.id, 'user:a');
    expect(library.ofKind(EffectKind.scene, builtInOnly: true).first.id,
        isNot('user:a'));
    expect(identical(library.byId('user:a'), library.byId('user:a')), isTrue,
        reason: 'the same scene is the same effect until edited');
    expect(library.byId('ocean')?.id, 'ocean');
    expect(library.byId('user:missing'), isNull);
  });
}
