import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/hue_buttons.dart';
import 'package:lumifx/src/features/fun/haunted_party.dart';

void main() {
  test('motion reports are read from the event stream, old and new', () {
    final data = jsonEncode([
      {
        'type': 'update',
        'data': [
          {
            'type': 'motion',
            'id': 'abc',
            'id_v1': '/sensors/5',
            'motion': {
              'motion': true,
              'motion_report': {'changed': 'x', 'motion': true},
            },
          },
          {
            'type': 'motion',
            'id': 'def',
            'id_v1': '/sensors/9',
            'motion': {'motion': false},
          },
          {
            'type': 'button',
            'id': 'b1',
            'button': {'last_event': 'short_release'},
          },
          {'type': 'light', 'id': 'l1'},
        ],
      },
    ]);
    final events = motionEventsOf(data);
    expect([for (final e in events) (e.sensorId, e.motion)],
        [('5', true), ('9', false)]);
    expect(buttonEventsOf(data), hasLength(1), reason: 'buttons still read');
    expect(motionEventsOf('not json'), isEmpty);
  });

  test('the spooky room never flashes fast', () {
    final room = HauntedParty.room('Halloween party');
    expect(room.hasRapidFlashes, isFalse);
    expect(HauntedParty.isParty(room), isTrue);
    expect(room.isGenerated, isTrue);
  });
}
