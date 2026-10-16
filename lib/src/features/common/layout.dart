import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Shared responsive rules. Widths are logical pixels.
abstract final class Breakpoints {
  /// Tablets and iPads, in portrait too: lists become grids and the
  /// player splits into two panes. Phones in landscape stay below it.
  static const double wide = 720;
}

extension LayoutContext on BuildContext {
  /// Whether the window is wide enough for the tablet layouts.
  bool get isWide => MediaQuery.sizeOf(this).width >= Breakpoints.wide;

  /// Padding for a scrolling page whose content should not stretch
  /// wider than [maxWidth]: the list still fills the window (so it
  /// scrolls from its edges), but the content sits centred.
  EdgeInsets pageInsets({
    double maxWidth = 720,
    double horizontal = 20,
    double top = 20,
    double bottom = 20,
  }) {
    final width = MediaQuery.sizeOf(this).width;
    final side = math.max(horizontal, (width - maxWidth) / 2 + horizontal);
    return EdgeInsets.fromLTRB(side, top, side, bottom);
  }
}
