import '../../color/light_color.dart';

/// The desired state of one light at one instant.
class LightFrame {
  const LightFrame(this.color, this.brightness);

  static const off = LightFrame(LightColor.black, 0);

  final LightColor color;

  /// 0..1. Values below [offThreshold] are treated as "off" by outputs.
  final double brightness;

  static const offThreshold = 0.005;

  bool get isOff => brightness < offThreshold;

  LightFrame withBrightness(double value) =>
      LightFrame(color, value.clamp(0.0, 1.0));

  /// Blends [overlay] on top of this frame with opacity [alpha] (0..1).
  LightFrame blend(LightFrame overlay, double alpha) {
    final a = alpha.clamp(0.0, 1.0);
    if (a == 0) {
      return this;
    }
    return LightFrame(
      LightColor.lerp(color, overlay.color, a),
      brightness + (overlay.brightness - brightness) * a,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LightFrame &&
      other.color == color &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(color, brightness);

  @override
  String toString() =>
      'LightFrame(${color.toHex()}, ${(brightness * 100).toStringAsFixed(1)}%)';
}
