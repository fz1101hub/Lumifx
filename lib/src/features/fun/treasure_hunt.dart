import 'dart:async';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/hue/hue_house.dart';

/// What kind of room a riddle is about, from the Hue room type.
enum RoomKind {
  living,
  kitchen,
  dining,
  bedroom,
  kids,
  bathroom,
  office,
  hallway,
  garden,
  other,
}

/// A treasure hunt across the house: a riddle read aloud for each room
/// in turn, the room lit as a hint, found with a tap, a motion sensor in
/// the room or an NFC sticker, and a golden treasure at the end.
abstract final class TreasureHunt {
  static const minSteps = 2;
  static const maxSteps = 5;

  /// The hint's glow and the found room's colour.
  static const gold = '#FFC94A';
  static const found = '#3DDC84';

  /// The kind of room of a Hue room type (`living_room`, `kids_bedroom`…).
  static RoomKind kindOf(String? archetype) => switch (archetype) {
        'living_room' || 'lounge' || 'tv' || 'recreation' => RoomKind.living,
        'kitchen' => RoomKind.kitchen,
        'dining' => RoomKind.dining,
        'bedroom' || 'guest_room' => RoomKind.bedroom,
        'kids_bedroom' || 'nursery' => RoomKind.kids,
        'bathroom' || 'toilet' => RoomKind.bathroom,
        'office' || 'computer' || 'studio' || 'reading' => RoomKind.office,
        'hallway' || 'staircase' || 'front_door' => RoomKind.hallway,
        'garden' || 'terrace' || 'balcony' || 'porch' => RoomKind.garden,
        _ => RoomKind.other,
      };

  /// The motion sensor in [room], by its name ("Hallway sensor" is in the
  /// Hallway), if any.
  static String? sensorIn(String room, List<HueMotionSensor> sensors) {
    final name = room.trim().toLowerCase();
    if (name.isEmpty) {
      return null;
    }
    return sensors
        .where((s) => s.name.toLowerCase().contains(name))
        .firstOrNull
        ?.id;
  }

  static final _stickers = StreamController<void>.broadcast();

  /// A treasure hunt sticker was tapped while the hunt is open.
  static Stream<void> get stickerTaps => _stickers.stream;

  static void stickerTapped() => _stickers.add(null);

  /// The treasure: the room sparkles gold.
  static LightingEffect treasure(String name) => LightingEffect(
        id: '${LightingEffect.generatedPrefix}treasure',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: const Duration(seconds: 30),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 30),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FFC94A', '#FFE9A8', '#FF9A2E', '#FFF4E5'],
              'brightnessMin': 0.6,
              'brightnessMax': 1.0,
              'speed': 0.25,
              'flicker': 0.5,
            },
          ),
          EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 4),
            type: EffectEventTypes.surprise,
            parameters: {'color': '#FFF4E5'},
          ),
        ],
      );
}
