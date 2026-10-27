import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/library/sentence_scene.dart';
import 'package:lumifx/src/features/library/user_scene.dart';

void main() {
  test('forest at sunset mixes both, in the order said', () {
    final scene = sceneFromSentence('Forest at sunset')!;
    expect(scene.colors, hasLength(UserScene.maxColors));
    expect(scene.colors.first, '#1E7F3A', reason: 'the forest first');
    expect(scene.colors[1], '#FF6A00', reason: 'then the sunset');
    expect(scene.motion, SceneMotion.drift);
  });

  test('the eight languages are understood', () {
    for (final sentence in [
      'bosco al tramonto',
      'Wald bei Sonnenuntergang',
      'forêt au coucher du soleil',
      'bosque al atardecer',
      'bos bij zonsondergang',
      'floresta ao pôr do sol',
      '夕焼けの森',
    ]) {
      final scene = sceneFromSentence(sentence);
      expect(scene, isNotNull, reason: sentence);
      expect(scene!.colors, containsAll(['#1E7F3A', '#FF6A00']),
          reason: sentence);
    }
  });

  test('motion comes from the things or from the words said', () {
    expect(sceneFromSentence('a campfire')!.motion, SceneMotion.flicker);
    expect(sceneFromSentence('notte stellata')!.motion, SceneMotion.calm);
    expect(sceneFromSentence('a lively sea')!.motion, SceneMotion.lively);
    expect(sceneFromSentence('funkelnde Sterne')!.motion, SceneMotion.flicker);
  });

  test('a longer word wins and short words must be whole', () {
    final sunset = sceneFromSentence('sunset')!;
    expect(sunset.colors, isNot(contains('#F9E04B')),
        reason: 'sunset is not the sun');
    expect(sceneFromSentence('merry christmas')!.colors,
        isNot(contains('#00B3FF')),
        reason: 'merry is not the sea');
  });

  test('unknown words give nothing', () {
    expect(sceneFromSentence('qwerty zxcv'), isNull);
    expect(sceneFromSentence(''), isNull);
  });
}
