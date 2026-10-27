import 'dart:math' as math;

import '../../core/hue/hue_bridge_client.dart';

/// Where each lamp sits on the light board, from 0 to 1 across and down.
typedef BoardSpot = ({double x, double y});

/// Places [lightIds] on the board: where an entertainment area put them
/// (seen from above, the TV at the top), the others on a ring around the
/// middle.
Map<String, BoardSpot> boardLayout(List<String> lightIds, HueHome? home) {
  final known = <String, BoardSpot>{};
  if (home != null) {
    final services = {
      for (final s in home.entertainmentServices) s.id: s.lightIds,
    };
    for (final area in home.entertainmentAreas) {
      for (final location in area.locations) {
        final position = location.positions.firstOrNull;
        if (position == null) {
          continue;
        }
        for (final light in services[location.serviceId] ?? const []) {
          // x runs left to right, y from the back (the TV) to the front.
          known.putIfAbsent(
              light,
              () => (
                    x: (position.x + 1) / 2 * 0.8 + 0.1,
                    y: (1 - position.y) / 2 * 0.8 + 0.1,
                  ));
        }
      }
    }
  }
  final others = [
    for (final id in lightIds)
      if (!known.containsKey(id)) id,
  ];
  return {
    for (final id in lightIds)
      if (known[id] case final spot?) id: spot,
    for (final (i, id) in others.indexed)
      id: others.length == 1
          ? (x: 0.5, y: 0.5)
          : (
              x: 0.5 +
                  0.36 *
                      math.cos(2 * math.pi * i / others.length - math.pi / 2),
              y: 0.5 +
                  0.36 *
                      math.sin(2 * math.pi * i / others.length - math.pi / 2),
            ),
  };
}

/// The lamp under a finger at [x], [y] (0 to 1), if any is within
/// [reach].
String? lampAt(Map<String, BoardSpot> layout, double x, double y,
    {double reach = 0.12}) {
  String? nearest;
  var best = reach * reach;
  for (final MapEntry(key: id, value: spot) in layout.entries) {
    final d = (spot.x - x) * (spot.x - x) + (spot.y - y) * (spot.y - y);
    if (d <= best) {
      best = d;
      nearest = id;
    }
  }
  return nearest;
}
