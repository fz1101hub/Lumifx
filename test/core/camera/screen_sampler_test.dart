import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/camera/screen_sampler.dart';
import 'package:lumifx/src/core/color/light_color.dart';

typedef Rgb = (int, int, int);

/// A BGRA frame (iOS) whose pixel at (x, y) is [paint](x, y), with some
/// padding at the end of each row as real buffers have.
CameraFrame bgra(int width, int height, Rgb Function(int x, int y) paint) {
  final rowBytes = width * 4 + 16;
  final bytes = Uint8List(rowBytes * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = paint(x, y);
      final i = y * rowBytes + x * 4;
      bytes[i] = b;
      bytes[i + 1] = g;
      bytes[i + 2] = r;
      bytes[i + 3] = 255;
    }
  }
  return CameraFrame(
    width: width,
    height: height,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes, bytesPerRow: rowBytes, bytesPerPixel: 4)],
  );
}

/// A YUV 4:2:0 frame (Android) with interleaved chroma (pixel stride 2).
CameraFrame yuv(int width, int height, Rgb Function(int x, int y) paint) {
  final cw = (width + 1) ~/ 2;
  final ch = (height + 1) ~/ 2;
  final yBytes = Uint8List(width * height);
  final uBytes = Uint8List(cw * 2 * ch);
  final vBytes = Uint8List(cw * 2 * ch);
  int clamp(double v) => v.round().clamp(0, 255);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = paint(x, y);
      final luma = 0.299 * r + 0.587 * g + 0.114 * b;
      yBytes[y * width + x] = clamp(luma);
      if (x.isEven && y.isEven) {
        final i = (y >> 1) * cw * 2 + (x >> 1) * 2;
        uBytes[i] = clamp(128 + (b - luma) / 1.772);
        vBytes[i] = clamp(128 + (r - luma) / 1.402);
      }
    }
  }
  return CameraFrame(
    width: width,
    height: height,
    format: FrameFormat.yuv420,
    planes: [
      FramePlane(yBytes, bytesPerRow: width, bytesPerPixel: 1),
      FramePlane(uBytes, bytesPerRow: cw * 2, bytesPerPixel: 2),
      FramePlane(vBytes, bytesPerRow: cw * 2, bytesPerPixel: 2),
    ],
  );
}

Rgb redLeftBlueRight(int x, int y, int width) =>
    x < width / 2 ? (230, 20, 20) : (20, 20, 230);

void expectHue(LightColor color, String hue) {
  final (r, g, b) = (color.r, color.g, color.b);
  switch (hue) {
    case 'red':
      expect(r, closeTo(1, 0.01));
      expect(b, lessThan(0.3));
    case 'blue':
      expect(b, closeTo(1, 0.01));
      expect(r, lessThan(0.3));
  }
  expect(g, lessThan(0.3));
}

void main() {
  for (final (name, make) in [('BGRA', bgra), ('YUV 4:2:0', yuv)]) {
    test('$name: zones follow the TV left to right', () {
      final frame = make(160, 120, (x, y) => redLeftBlueRight(x, y, 160));
      final colors = sampleScreen(frame, zones: 2)!;
      expect(colors.zones, 2);
      expectHue(colors.colors[0], 'red');
      expectHue(colors.colors[1], 'blue');
      expect(colors.levels[0], closeTo(0.9, 0.05));
    });

    test('$name: turning the picture upright swaps or rotates the zones', () {
      final frame = make(160, 120, (x, y) => redLeftBlueRight(x, y, 160));
      final turned = sampleScreen(frame, zones: 2, quarterTurns: 2)!;
      expectHue(turned.colors[0], 'blue');
      expectHue(turned.colors[1], 'red');

      // Sensor top/bottom becomes the TV's right/left with one turn.
      final tall =
          make(120, 160, (x, y) => y < 80 ? (230, 20, 20) : (20, 20, 230));
      final once = sampleScreen(tall, zones: 2, quarterTurns: 1)!;
      expectHue(once.colors[0], 'blue');
      expectHue(once.colors[1], 'red');
      final thrice = sampleScreen(tall, zones: 2, quarterTurns: 3)!;
      expectHue(thrice.colors[0], 'red');
      expectHue(thrice.colors[1], 'blue');
    });
  }

  test('only the middle of the picture counts', () {
    // A bright wall around a dark TV.
    final frame = bgra(200, 100, (x, y) {
      final inside = x > 40 && x < 160 && y > 20 && y < 80;
      return inside ? (10, 10, 60) : (255, 255, 255);
    });
    final colors = sampleScreen(frame, zones: 1, cover: 0.5)!;
    expect(colors.levels.single, lessThan(0.3));
  });

  test('a dark picture turns the lights down, not to a random colour', () {
    final colors = sampleScreen(bgra(64, 48, (_, __) => (2, 3, 1)))!;
    expect(colors.levels, everyElement(0.0));
  });

  test('greyish averages get a little more colour', () {
    final colors = sampleScreen(
      bgra(64, 48, (_, __) => (200, 150, 150)),
      zones: 1,
    )!;
    final color = colors.colors.single;
    expect(color.r, 1);
    // 0.75 of the peak without the boost; less with it.
    expect(color.g, lessThan(0.72));
    expect(color.g, closeTo(color.b, 0.001));
  });

  test('frames it cannot read give nothing instead of crashing', () {
    final good = bgra(64, 48, (_, __) => (100, 100, 100));
    final short = CameraFrame(
      width: 64,
      height: 48,
      format: FrameFormat.bgra8888,
      planes: [
        FramePlane(Uint8List(100), bytesPerRow: good.planes[0].bytesPerRow),
      ],
    );
    expect(sampleScreen(short), isNull);
    expect(
      sampleScreen(CameraFrame(
        width: 64,
        height: 48,
        format: FrameFormat.yuv420,
        planes: [good.planes[0]],
      )),
      isNull,
    );
    expect(
      sampleScreen(const CameraFrame(
        width: 0,
        height: 0,
        format: FrameFormat.bgra8888,
        planes: [],
      )),
      isNull,
    );
  });

  test('colours average over zones and blend between frames', () {
    const a = ScreenColors(
      [LightColor(1, 0, 0), LightColor(0, 0, 1)],
      [1, 0.5],
    );
    final (color, level) = a.average(0, 2);
    expect(level, closeTo(0.75, 1e-9));
    expect(color.r, 1);
    expect(color.b, closeTo(0.5, 1e-9));
    expect(a.average(0, 0).$2, 0);

    const b = ScreenColors(
      [LightColor(0, 1, 0), LightColor(0, 1, 0)],
      [0, 1],
    );
    final half = a.towards(b, 0.5);
    expect(half.levels, [0.5, 0.75]);
    expect(half.colors.first.g, 0.5);
  });
}
