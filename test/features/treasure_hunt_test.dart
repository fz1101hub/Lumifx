import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/hue_house.dart';
import 'package:lumifx/src/features/fun/treasure_hunt.dart';

void main() {
  test('Hue room types give the riddle of their kind', () {
    expect(TreasureHunt.kindOf('kids_bedroom'), RoomKind.kids);
    expect(TreasureHunt.kindOf('nursery'), RoomKind.kids);
    expect(TreasureHunt.kindOf('toilet'), RoomKind.bathroom);
    expect(TreasureHunt.kindOf('terrace'), RoomKind.garden);
    expect(TreasureHunt.kindOf('attic'), RoomKind.other);
    expect(TreasureHunt.kindOf(null), RoomKind.other);
  });

  test("a room's motion sensor is found by its name", () {
    const sensors = [
      HueMotionSensor(id: '1', name: 'Hallway sensor'),
      HueMotionSensor(id: '2', name: 'Kitchen motion'),
    ];
    expect(TreasureHunt.sensorIn('Kitchen', sensors), '2');
    expect(TreasureHunt.sensorIn('hallway', sensors), '1');
    expect(TreasureHunt.sensorIn('Attic', sensors), isNull);
    expect(TreasureHunt.sensorIn(' ', sensors), isNull);
  });

  test('a sticker tap reaches the hunt', () async {
    final taps = <void>[];
    final listening = TreasureHunt.stickerTaps.listen(taps.add);
    TreasureHunt.stickerTapped();
    await Future<void>.delayed(Duration.zero);
    expect(taps, hasLength(1));
    await listening.cancel();
  });
}
