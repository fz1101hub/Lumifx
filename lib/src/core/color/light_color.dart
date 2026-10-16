import 'dart:math' as math;

/// A device-independent RGB color with channels in the 0..1 range.
///
/// Effects are authored in sRGB (usually as `#RRGGBB` strings) and converted
/// to CIE xy only at the edge, when a frame is sent to a Hue light.
class LightColor {
  const LightColor(this.r, this.g, this.b);

  /// Parses `#RRGGBB` or `RRGGBB`.
  factory LightColor.fromHex(String hex) {
    final value = hex.startsWith('#') ? hex.substring(1) : hex;
    if (value.length != 6) {
      throw FormatException('Expected #RRGGBB color', hex);
    }
    final rgb = int.parse(value, radix: 16);
    return LightColor(
      ((rgb >> 16) & 0xFF) / 255,
      ((rgb >> 8) & 0xFF) / 255,
      (rgb & 0xFF) / 255,
    );
  }

  /// The colour of CIE 1931 chromaticity [x], [y] at full brightness: the
  /// inverse of [toXy], scaled so the strongest channel is 1.
  factory LightColor.fromXy(double x, double y) {
    if (y <= 0) {
      return white;
    }
    final bigX = x / y;
    final bigZ = (1 - x - y) / y;
    var red = bigX * 1.656492 - 0.354851 - bigZ * 0.255038;
    var green = -bigX * 0.707196 + 1.655397 + bigZ * 0.036152;
    var blue = bigX * 0.051713 - 0.121364 + bigZ * 1.011530;
    double ungamma(double c) => c <= 0.0031308
        ? 12.92 * c
        : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
    red = ungamma(math.max(red, 0));
    green = ungamma(math.max(green, 0));
    blue = ungamma(math.max(blue, 0));
    final peak = math.max(red, math.max(green, blue));
    if (peak <= 0) {
      return white;
    }
    return LightColor(red / peak, green / peak, blue / peak);
  }

  /// The white of a colour temperature in mirek (Tanner Helland's
  /// approximation of the black-body colours, 1000-40000 K).
  factory LightColor.fromMirek(int mirek) {
    final kelvin = (1e6 / mirek.clamp(25, 1000)) / 100;
    double clamp(double v) => (v / 255).clamp(0.0, 1.0);
    final red = kelvin <= 66
        ? 1.0
        : clamp(329.698727446 * math.pow(kelvin - 60, -0.1332047592));
    final green = kelvin <= 66
        ? clamp(99.4708025861 * math.log(kelvin) - 161.1195681661)
        : clamp(288.1221695283 * math.pow(kelvin - 60, -0.0755148492));
    final blue = kelvin >= 66
        ? 1.0
        : kelvin <= 19
            ? 0.0
            : clamp(138.5177312231 * math.log(kelvin - 10) - 305.0447927307);
    return LightColor(red, green, blue);
  }

  static const black = LightColor(0, 0, 0);
  static const white = LightColor(1, 1, 1);

  final double r;
  final double g;
  final double b;

  /// Linear interpolation between [a] and [b]; [t] is clamped to 0..1.
  static LightColor lerp(LightColor a, LightColor b, double t) {
    final k = t.clamp(0.0, 1.0);
    return LightColor(
      a.r + (b.r - a.r) * k,
      a.g + (b.g - a.g) * k,
      a.b + (b.b - a.b) * k,
    );
  }

  String toHex() {
    String channel(double v) =>
        (v.clamp(0.0, 1.0) * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${channel(r)}${channel(g)}${channel(b)}'.toUpperCase();
  }

  /// Converts to CIE 1931 xy using the wide-gamut D65 matrix recommended by
  /// Philips Hue. The bridge clamps out-of-gamut values to each lamp's gamut.
  ({double x, double y}) toXy() {
    double gamma(double c) =>
        c > 0.04045 ? math.pow((c + 0.055) / 1.055, 2.4).toDouble() : c / 12.92;

    final red = gamma(r);
    final green = gamma(g);
    final blue = gamma(b);

    final x = red * 0.664511 + green * 0.154324 + blue * 0.162028;
    final y = red * 0.283881 + green * 0.668433 + blue * 0.047685;
    final z = red * 0.000088 + green * 0.072310 + blue * 0.986039;
    final sum = x + y + z;
    if (sum == 0) {
      // Black has no chromaticity; use the D65 white point.
      return (x: 0.3127, y: 0.3290);
    }
    return (x: x / sum, y: y / sum);
  }

  @override
  bool operator ==(Object other) =>
      other is LightColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'LightColor(${toHex()})';
}
