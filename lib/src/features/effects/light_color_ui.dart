import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/color/light_color.dart';
import '../../core/effects/engine/light_frame.dart';

extension LightColorUi on LightColor {
  Color toColor() => Color.fromARGB(
        255,
        (r.clamp(0.0, 1.0) * 255).round(),
        (g.clamp(0.0, 1.0) * 255).round(),
        (b.clamp(0.0, 1.0) * 255).round(),
      );
}

extension LightFrameUi on LightFrame {
  /// How the light would look on screen: dimmer frames are darker. A gentle
  /// curve keeps low brightness levels visible.
  Color toDisplayColor() {
    final level = math.pow(brightness.clamp(0.0, 1.0), 0.6).toDouble();
    return Color.lerp(const Color(0xFF000000), color.toColor(), level)!;
  }
}
