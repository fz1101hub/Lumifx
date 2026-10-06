import 'package:flutter/painting.dart';

import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import 'light_color_ui.dart';

/// Colors that represent an effect in the UI: every palette and event color
/// it uses, in timeline order.
List<Color> effectPalette(LightingEffect effect) {
  final colors = <Color>[];
  for (final event in effect.events) {
    final palette = event.parameters['palette'];
    if (palette is List) {
      colors.addAll(palette.whereType<String>().map(_parse));
    }
    final color = event.parameters['color'];
    if (color is String) {
      colors.add(_parse(color));
    }
  }
  return colors.isEmpty ? const [Color(0xFF444444)] : colors;
}

Color _parse(String hex) => LightColor.fromHex(hex).toColor();
