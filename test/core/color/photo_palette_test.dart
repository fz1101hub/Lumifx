import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/color/photo_palette.dart';

/// Raw RGBA pixels: [count] of each colour, in order.
Uint8List _pixels(List<(int, (int, int, int, int))> runs) {
  final bytes = <int>[];
  for (final (count, (r, g, b, a)) in runs) {
    for (var i = 0; i < count; i++) {
      bytes.addAll([r, g, b, a]);
    }
  }
  return Uint8List.fromList(bytes);
}

/// A PNG with a band of each colour, as a photo would arrive.
Future<Uint8List> _png(List<ui.Color> bands) async {
  const size = 40.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final width = size / bands.length;
  for (final (i, color) in bands.indexed) {
    canvas.drawRect(
      ui.Rect.fromLTWH(i * width, 0, width, size),
      ui.Paint()..color = color,
    );
  }
  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the main colours, most present first', () {
    final palette = paletteFromRgba(_pixels([
      (60, (255, 0, 0, 255)),
      (40, (0, 0, 255, 255)),
    ]));
    expect(palette, ['#FF0000', '#0000FF']);
  });

  test('dark and see-through pixels do not count', () {
    final palette = paletteFromRgba(_pixels([
      (500, (5, 5, 10, 255)),
      (300, (255, 0, 0, 10)),
      (20, (0, 255, 0, 255)),
    ]));
    // Green alone, with a neighbour so the scene still moves.
    expect(palette, hasLength(2));
    expect(palette.first, '#00FF00');
  });

  test('colours too close to one another count as one', () {
    final palette = paletteFromRgba(_pixels([
      (50, (255, 0, 0, 255)),
      (30, (255, 68, 0, 255)), // A red with a touch of orange.
      (20, (0, 0, 255, 255)),
    ]));
    expect(palette, ['#FF0000', '#0000FF']);
  });

  test('washed-out colours come out stronger, at full brightness', () {
    final palette = paletteFromRgba(_pixels([(10, (150, 180, 230, 255))]));
    final blue = LightColor.fromHex(palette.first);
    expect(blue.b, 1.0);
    expect(blue.r, lessThan(0.45), reason: 'saturated enough to see');
  });

  test('pale photos give whites; black ones warm whites', () {
    final pale = paletteFromRgba(_pixels([(10, (240, 240, 235, 255))]));
    expect(pale, hasLength(2));
    final white = LightColor.fromHex(pale.first);
    expect(white.r, 1.0);
    expect(white.b, greaterThan(0.8));

    expect(paletteFromRgba(_pixels([(10, (0, 0, 0, 255))])),
        ['#FFD7A8', '#FFF4E5']);
    expect(paletteFromRgba(Uint8List(0)), hasLength(2));
  });

  test('never more colours than asked', () {
    final palette = paletteFromRgba(_pixels([
      for (var hue = 0; hue < 8; hue++)
        (
          10 + hue,
          (switch (hue % 4) {
            0 => (255, 0, 0, 255),
            1 => (0, 255, 0, 255),
            2 => (0, 0, 255, 255),
            _ => (255, 255, 0, 255),
          })
        ),
      (12, (255, 0, 255, 255)),
      (13, (0, 255, 255, 255)),
      (14, (255, 128, 0, 255)),
    ]));
    expect(palette, hasLength(5));
    expect(palette.toSet(), hasLength(5));
  });

  test('reads the colours of an encoded photo', () async {
    final png = await _png(const [
      ui.Color(0xFFFF0000),
      ui.Color(0xFFFF0000),
      ui.Color(0xFF00FF00),
    ]);
    final palette = await paletteFromImage(png);
    expect(palette, hasLength(2));
    // Resizing blends the edges a little.
    final [red, green] = [for (final hex in palette) LightColor.fromHex(hex)];
    expect((red.r, red.g < 0.05, red.b), (1.0, true, 0.0));
    expect((green.r < 0.05, green.g, green.b < 0.05), (true, 1.0, true));
  });
}
