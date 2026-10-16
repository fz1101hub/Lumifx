import 'dart:math' as math;
import 'dart:typed_data';

import '../color/light_color.dart';

/// What the camera sees of the TV: one colour per zone, left to right
/// across the screen, each at full value with its own brightness.
class ScreenColors {
  /// [colors] and [levels] have one entry per zone.
  const ScreenColors(this.colors, this.levels);

  /// At full value: the strongest channel is 1.
  final List<LightColor> colors;

  /// 0..1 per zone.
  final List<double> levels;

  int get zones => colors.length;

  /// The average of zones [start] (inclusive) to [end] (exclusive).
  (LightColor, double) average(int start, int end) {
    var r = 0.0, g = 0.0, b = 0.0, level = 0.0;
    final count = math.max(1, end - start);
    for (var i = start; i < end; i++) {
      r += colors[i].r * levels[i];
      g += colors[i].g * levels[i];
      b += colors[i].b * levels[i];
      level += levels[i];
    }
    final peak = math.max(r, math.max(g, b));
    if (peak <= 0) {
      return (LightColor.black, 0);
    }
    return (LightColor(r / peak, g / peak, b / peak), level / count);
  }

  /// Moves every zone [t] (0..1) of the way from this towards [next].
  ScreenColors towards(ScreenColors next, double t) {
    if (next.zones != zones) {
      return next;
    }
    return ScreenColors(
      [
        for (var i = 0; i < zones; i++)
          LightColor.lerp(colors[i], next.colors[i], t),
      ],
      [
        for (var i = 0; i < zones; i++)
          levels[i] + (next.levels[i] - levels[i]) * t,
      ],
    );
  }
}

/// How the bytes of a camera frame are laid out.
enum FrameFormat {
  /// Three planes: Y at full size, then U and V at half size; each plane
  /// has its own row and pixel stride (Android).
  yuv420,

  /// One plane of 4-byte pixels, blue, green, red, alpha (iOS).
  bgra8888,
}

/// One plane of a camera frame.
class FramePlane {
  const FramePlane(this.bytes, {required this.bytesPerRow, this.bytesPerPixel});

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// A camera frame, as the sensor delivers it (not yet turned upright).
class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });

  final int width;
  final int height;
  final FrameFormat format;
  final List<FramePlane> planes;
}

/// The colours of [zones] slices of the middle of [frame], left to right
/// as the user sees it: [quarterTurns] clockwise turns make the sensor's
/// picture upright. Only the central [cover] of each side is looked at,
/// so the TV's surroundings matter less. Reads about 4000 pixels however
/// big the frame is. Null for a frame it cannot read.
ScreenColors? sampleScreen(
  CameraFrame frame, {
  int zones = 8,
  int quarterTurns = 0,
  double cover = 0.7,
  double saturationBoost = 1.25,
}) {
  final width = frame.width;
  final height = frame.height;
  if (width < 2 || height < 2 || zones < 1 || !_readable(frame)) {
    return null;
  }
  final turns = quarterTurns % 4;
  // Upright "left to right" runs along x for 0 and 2 turns, along y for 1
  // and 3; reversed for 1 and 2.
  final alongX = turns.isEven;
  final reversed = turns == 1 || turns == 2;
  final x0 = (width * (1 - cover) / 2).floor();
  final x1 = (width * (1 + cover) / 2).ceil().clamp(x0 + 1, width);
  final y0 = (height * (1 - cover) / 2).floor();
  final y1 = (height * (1 + cover) / 2).ceil().clamp(y0 + 1, height);
  final spanX = x1 - x0;
  final spanY = y1 - y0;
  // About 64 samples along the width of the TV and 48 across it.
  final stepAlong = math.max(1, (alongX ? spanX : spanY) ~/ 64);
  final stepAcross = math.max(1, (alongX ? spanY : spanX) ~/ 48);
  final stepX = alongX ? stepAlong : stepAcross;
  final stepY = alongX ? stepAcross : stepAlong;

  final sumR = Float64List(zones);
  final sumG = Float64List(zones);
  final sumB = Float64List(zones);
  final counts = Int32List(zones);
  final read = _reader(frame);
  for (var y = y0; y < y1; y += stepY) {
    for (var x = x0; x < x1; x += stepX) {
      final along = alongX ? (x - x0) / spanX : (y - y0) / spanY;
      var zone = (along * zones).floor().clamp(0, zones - 1);
      if (reversed) {
        zone = zones - 1 - zone;
      }
      final (r, g, b) = read(x, y);
      sumR[zone] += r;
      sumG[zone] += g;
      sumB[zone] += b;
      counts[zone]++;
    }
  }

  final colors = <LightColor>[];
  final levels = <double>[];
  for (var i = 0; i < zones; i++) {
    final n = math.max(1, counts[i]);
    final (color, level) = _vivid(
      sumR[i] / n / 255,
      sumG[i] / n / 255,
      sumB[i] / n / 255,
      saturationBoost,
    );
    colors.add(color);
    levels.add(level);
  }
  return ScreenColors(colors, levels);
}

bool _readable(CameraFrame frame) {
  switch (frame.format) {
    case FrameFormat.yuv420:
      if (frame.planes.length < 3) {
        return false;
      }
      final y = frame.planes[0];
      final u = frame.planes[1];
      final v = frame.planes[2];
      final chromaW = (frame.width + 1) ~/ 2;
      final chromaH = (frame.height + 1) ~/ 2;
      final uStride = u.bytesPerPixel ?? 1;
      final vStride = v.bytesPerPixel ?? 1;
      return y.bytesPerRow >= frame.width &&
          y.bytes.length >= y.bytesPerRow * (frame.height - 1) + frame.width &&
          u.bytes.length >=
              u.bytesPerRow * (chromaH - 1) + (chromaW - 1) * uStride + 1 &&
          v.bytes.length >=
              v.bytesPerRow * (chromaH - 1) + (chromaW - 1) * vStride + 1;
    case FrameFormat.bgra8888:
      if (frame.planes.isEmpty) {
        return false;
      }
      final p = frame.planes[0];
      return p.bytesPerRow >= frame.width * 4 &&
          p.bytes.length >=
              p.bytesPerRow * (frame.height - 1) + frame.width * 4;
  }
}

/// Reads the sRGB colour (0..255 per channel) of a pixel.
(double, double, double) Function(int x, int y) _reader(CameraFrame frame) {
  switch (frame.format) {
    case FrameFormat.yuv420:
      final yp = frame.planes[0];
      final up = frame.planes[1];
      final vp = frame.planes[2];
      final uStride = up.bytesPerPixel ?? 1;
      final vStride = vp.bytesPerPixel ?? 1;
      return (x, y) {
        final luma = yp.bytes[y * yp.bytesPerRow + x].toDouble();
        final cx = x >> 1;
        final cy = y >> 1;
        final u = up.bytes[cy * up.bytesPerRow + cx * uStride] - 128.0;
        final v = vp.bytes[cy * vp.bytesPerRow + cx * vStride] - 128.0;
        return (
          (luma + 1.402 * v).clamp(0.0, 255.0),
          (luma - 0.344136 * u - 0.714136 * v).clamp(0.0, 255.0),
          (luma + 1.772 * u).clamp(0.0, 255.0),
        );
      };
    case FrameFormat.bgra8888:
      final p = frame.planes[0];
      return (x, y) {
        final i = y * p.bytesPerRow + x * 4;
        return (
          p.bytes[i + 2].toDouble(),
          p.bytes[i + 1].toDouble(),
          p.bytes[i].toDouble(),
        );
      };
  }
}

/// The average colour at full value with a little more saturation (a TV
/// picture averaged over a zone turns greyish), and its brightness.
(LightColor, double) _vivid(double r, double g, double b, double boost) {
  final peak = math.max(r, math.max(g, b));
  if (peak <= 0.02) {
    return (LightColor.black, 0);
  }
  final low = math.min(r, math.min(g, b));
  final saturation = (peak - low) / peak;
  final boosted = (saturation * boost).clamp(0.0, 1.0);
  // Push each channel away from the peak to the boosted saturation.
  double channel(double c) {
    if (saturation <= 0) {
      return 1;
    }
    final relative = (peak - c) / (peak - low); // 0 at peak, 1 at low
    return 1 - boosted * relative;
  }

  return (LightColor(channel(r), channel(g), channel(b)), peak);
}
