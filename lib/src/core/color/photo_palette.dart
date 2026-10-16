import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'light_color.dart';

/// Warm whites, for photos with no colour to speak of.
const _plainWhites = ['#FFD7A8', '#FFF4E5'];

/// The main colours of a photo, as `#RRGGBB`, most present first: two to
/// [count] of them, distinct enough to tell apart on the lights. Decoded
/// small, on the phone; the photo itself is not kept.
Future<List<String>> paletteFromImage(Uint8List bytes, {int count = 5}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return _plainWhites;
      }
      return paletteFromRgba(data.buffer.asUint8List(), count: count);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// [paletteFromImage] on raw RGBA pixels.
///
/// Pixels are grouped by hue; vivid ones count more than dull ones, dark
/// and see-through ones not at all, and pale ones go to a group of their
/// own, the whites. Each colour is the average of its group, made bright
/// and a little more saturated: a light shows a washed-out blue as grey.
List<String> paletteFromRgba(Uint8List rgba, {int count = 5}) {
  assert(count >= 2);
  const hueBins = 24;
  final weight = List<double>.filled(hueBins + 1, 0);
  final red = List<double>.filled(hueBins + 1, 0);
  final green = List<double>.filled(hueBins + 1, 0);
  final blue = List<double>.filled(hueBins + 1, 0);
  var total = 0.0;

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) {
      continue;
    }
    final r = rgba[i] / 255, g = rgba[i + 1] / 255, b = rgba[i + 2] / 255;
    final (hue, saturation, value) = _hsv(r, g, b);
    if (value < 0.18) {
      continue;
    }
    final int bin;
    final double w;
    if (saturation < 0.22) {
      if (value < 0.6) {
        continue; // Greys light nothing up.
      }
      bin = hueBins;
      w = 0.35;
    } else {
      bin = (hue / 360 * hueBins).floor() % hueBins;
      w = 0.3 + saturation * value;
    }
    weight[bin] += w;
    red[bin] += r * w;
    green[bin] += g * w;
    blue[bin] += b * w;
    total += w;
  }
  if (total == 0) {
    return _plainWhites;
  }

  final order = [for (var i = 0; i <= hueBins; i++) i]
    ..sort((a, b) => weight[b].compareTo(weight[a]));
  final picked = <(double, LightColor)>[];
  for (final bin in order) {
    if (picked.length == count || weight[bin] < total * 0.02) {
      break;
    }
    final w = weight[bin];
    final (hue, saturation, _) =
        _hsv(red[bin] / w, green[bin] / w, blue[bin] / w);
    final isWhite = bin == hueBins;
    if (!isWhite &&
        picked.any((p) => p.$1 >= 0 && _hueDistance(p.$1, hue) < 22)) {
      continue; // Too close to a colour already taken.
    }
    final color = isWhite
        ? _fromHsv(hue, math.min(saturation, 0.2), 1)
        : _fromHsv(hue, math.max(saturation, 0.6), 1);
    picked.add((isWhite ? -1 : hue, color));
  }

  final colors = [for (final (_, color) in picked) color.toHex()];
  if (colors.length == 1) {
    // One colour only: pair it with a neighbour, so the scene still moves.
    final (hue, _) = picked.single;
    colors.add(hue < 0
        ? _plainWhites.first
        : _fromHsv((hue + 30) % 360, 0.7, 1).toHex());
  }
  return colors.isEmpty ? _plainWhites : colors;
}

(double, double, double) _hsv(double r, double g, double b) {
  final high = math.max(r, math.max(g, b));
  final low = math.min(r, math.min(g, b));
  final delta = high - low;
  var hue = 0.0;
  if (delta > 0) {
    if (high == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (high == g) {
      hue = 60 * ((b - r) / delta + 2);
    } else {
      hue = 60 * ((r - g) / delta + 4);
    }
  }
  return ((hue + 360) % 360, high == 0 ? 0.0 : delta / high, high);
}

LightColor _fromHsv(double hue, double saturation, double value) {
  final c = value * saturation;
  final x = c * (1 - ((hue / 60) % 2 - 1).abs());
  final m = value - c;
  final (r, g, b) = switch (hue) {
    < 60 => (c, x, 0.0),
    < 120 => (x, c, 0.0),
    < 180 => (0.0, c, x),
    < 240 => (0.0, x, c),
    < 300 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  return LightColor(r + m, g + m, b + m);
}

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}
