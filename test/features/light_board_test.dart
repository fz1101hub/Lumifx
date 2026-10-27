import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/board/light_board.dart';

void main() {
  test('lamps of an entertainment area keep their place, others ring', () {
    const home = HueHome(
      lights: {},
      rooms: [],
      zones: [],
      entertainmentServices: [
        HueEntertainmentService(id: 'e1', lightIds: ['l1']),
      ],
      entertainmentAreas: [
        HueEntertainmentArea(
          id: 'a',
          name: 'TV',
          channels: [],
          locations: [
            HueServiceLocation(serviceId: 'e1', positions: [
              HuePosition(-1, 1),
            ]),
          ],
        ),
      ],
    );
    final layout = boardLayout(['l1', 'l2', 'l3'], home);
    expect(layout['l1']!.x, closeTo(0.1, 1e-9), reason: 'left');
    expect(layout['l1']!.y, closeTo(0.1, 1e-9), reason: 'back, by the TV');
    expect(layout['l2']!.x, closeTo(0.5, 1e-9));
    expect(layout['l2']!.y, closeTo(0.14, 1e-9), reason: 'top of the ring');
    expect(layout['l3']!.y, closeTo(0.86, 1e-9));
    expect(boardLayout(['solo'], null)['solo'], (x: 0.5, y: 0.5));
  });

  test('the finger finds the nearest lamp within reach', () {
    final layout = {
      'a': (x: 0.2, y: 0.2),
      'b': (x: 0.3, y: 0.2),
    };
    expect(lampAt(layout, 0.22, 0.21), 'a');
    expect(lampAt(layout, 0.29, 0.2), 'b');
    expect(lampAt(layout, 0.8, 0.8), isNull);
  });
}
