import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/fun/hide_and_seek.dart';

void main() {
  test('the lamps dim while counting, then a dim blue room to search', () {
    final effect = HideAndSeek.effect('Hide and seek', 20);
    expect(effect.keepsRealTime, isTrue);
    expect(effect.hasRapidFlashes, isFalse);
    expect(HideAndSeek.countOf(effect), 20);
    final renderer = EffectRenderer(effect, slotCount: 2, seed: 1);
    final start = renderer.render(const Duration(seconds: 1)).first;
    final late = renderer.render(const Duration(seconds: 18)).first;
    expect(start.brightness, greaterThan(0.6));
    expect(late.brightness, lessThan(0.2));
    final searching = renderer.render(const Duration(seconds: 25)).first;
    expect(searching.color.b, greaterThan(searching.color.r));
    expect(HideAndSeek.found('Found').hasRapidFlashes, isFalse);
  });
}
