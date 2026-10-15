import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';

void main() {
  test('parses and formats hex colors', () {
    final color = LightColor.fromHex('#FFD84D');
    expect(color.r, 1);
    expect(color.toHex(), '#FFD84D');
    expect(LightColor.fromHex('063b20').toHex(), '#063B20');
  });

  test('rejects malformed hex', () {
    expect(() => LightColor.fromHex('#FFF'), throwsFormatException);
  });

  test('converts primaries to the expected CIE xy region', () {
    final red = const LightColor(1, 0, 0).toXy();
    expect(red.x, closeTo(0.70, 0.02));
    expect(red.y, closeTo(0.30, 0.02));

    final blue = const LightColor(0, 0, 1).toXy();
    expect(blue.x, closeTo(0.14, 0.02));
    expect(blue.y, closeTo(0.04, 0.02));

    final white = LightColor.white.toXy();
    expect(white.x, closeTo(0.32, 0.02));
    expect(white.y, closeTo(0.33, 0.02));
  });

  test('black falls back to the white point', () {
    final xy = LightColor.black.toXy();
    expect(xy.x, closeTo(0.3127, 1e-4));
  });
}
