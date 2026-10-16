import 'hue_schedules.dart';

/// Lights on in the evening and off at night while nobody is home, room
/// after room, at times that change a little every day. Kept as the
/// bridge's own schedules, so it runs with the phone away.
class HueAwayMode {
  const HueAwayMode({
    required this.token,
    required this.name,
    required this.groupIds,
    required this.onHour,
    required this.onMinute,
    required this.offHour,
    required this.offMinute,
    required this.days,
    required this.enabled,
    required this.scheduleIds,
  });

  final String token;
  final String name;

  /// The v1 ids of the rooms, in the order they light up.
  final List<String> groupIds;
  final int onHour;
  final int onMinute;
  final int offHour;
  final int offMinute;

  /// The evenings it runs, 0 (Monday) to 6.
  final List<int> days;
  final bool enabled;
  final List<String> scheduleIds;
}

class HueAwayModeDraft {
  const HueAwayModeDraft({
    required this.name,
    required this.groupIds,
    required this.onHour,
    required this.onMinute,
    required this.offHour,
    required this.offMinute,
    required this.days,
  });

  final String name;
  final List<String> groupIds;
  final int onHour;
  final int onMinute;
  final int offHour;
  final int offMinute;
  final List<int> days;

  static const maxRooms = 4;

  /// Each room starts this much after the one before…
  static const staggerMinutes = 15;

  /// …and the bridge adds up to this much at random, every day anew.
  static const randomMinutes = 30;

  /// A warm, lived-in white.
  static const brightness = 200;
  static const mirek = 366;
}

/// The bridge's `localtime` like [scheduleLocaltime], with up to
/// [randomMinutes] added at random by the bridge each time.
String randomLocaltime({
  required int hour,
  required int minute,
  required List<int> days,
  required DateTime now,
  required int randomMinutes,
}) {
  final base =
      scheduleLocaltime(hour: hour, minute: minute, days: days, now: now);
  final h = (randomMinutes ~/ 60).toString().padLeft(2, '0');
  final m = (randomMinutes % 60).toString().padLeft(2, '0');
  return '${base}A$h:$m:00';
}

/// Reads back [randomLocaltime]: the time, days and random minutes.
({int hour, int minute, List<int> days, int randomMinutes})?
    parseRandomLocaltime(String localtime) {
  final match = RegExp(r'^(.+)A(\d\d):(\d\d):\d\d$').firstMatch(localtime);
  final base = parseLocaltime(match?.group(1) ?? localtime);
  if (base == null) {
    return null;
  }
  return (
    hour: base.hour,
    minute: base.minute,
    days: base.days,
    randomMinutes: match == null
        ? 0
        : int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!),
  );
}

/// A Hue motion sensor (its presence part), by its older-API id.
class HueMotionSensor {
  const HueMotionSensor({required this.id, required this.name});

  final String id;
  final String name;
}

/// At night, motion on a sensor turns a room's lights on, dim and warm,
/// and off again a few minutes after the last motion. Kept as two rules
/// on the bridge.
class HueNightPath {
  const HueNightPath({
    required this.onRuleId,
    required this.offRuleId,
    required this.sensorId,
    required this.groupId,
    required this.fromHour,
    required this.fromMinute,
    required this.toHour,
    required this.toMinute,
    required this.minutes,
    required this.enabled,
  });

  final String onRuleId;
  final String offRuleId;
  final String sensorId;

  /// The v1 id of the room.
  final String groupId;
  final int fromHour;
  final int fromMinute;
  final int toHour;
  final int toMinute;

  /// How long the light stays after the last motion.
  final int minutes;
  final bool enabled;

  List<String> get ruleIds => [onRuleId, offRuleId];
}

class HueNightPathDraft {
  const HueNightPathDraft({
    required this.sensorId,
    required this.groupId,
    required this.fromHour,
    required this.fromMinute,
    required this.toHour,
    required this.toMinute,
    required this.minutes,
  });

  final String sensorId;
  final String groupId;
  final int fromHour;
  final int fromMinute;
  final int toHour;
  final int toMinute;
  final int minutes;

  static const minuteChoices = [2, 5, 10];

  /// Dim amber, enough to find the way without waking up.
  static const brightness = 30;
  static const xy = (x: 0.5873, y: 0.3776);

  /// The lights may still switch off this long after the night ends.
  static const offGraceMinutes = 30;
}

/// One part of the day for natural light.
class NaturalLightSlot {
  const NaturalLightSlot(this.hour, this.minute, this.mirek, this.brightness);

  final int hour;
  final int minute;

  /// Colour temperature: high is warm.
  final int mirek;

  /// 0..100.
  final double brightness;

  /// From a fresh morning to a warm, dim night.
  static const day = [
    NaturalLightSlot(6, 30, 250, 60), // 4000 K
    NaturalLightSlot(9, 0, 200, 100), // 5000 K
    NaturalLightSlot(17, 0, 286, 90), // 3500 K
    NaturalLightSlot(19, 30, 370, 70), // 2700 K
    NaturalLightSlot(21, 30, 454, 35), // 2200 K
  ];
}

/// Whites that follow the day in a room: a smart scene on the bridge
/// that moves from one part of the day to the next while active.
class HueNaturalLight {
  const HueNaturalLight({
    required this.id,
    required this.name,
    required this.groupId,
    required this.sceneIds,
    required this.active,
  });

  final String id;
  final String name;

  /// The v2 id of the room or zone.
  final String groupId;

  /// The scenes of the parts of the day.
  final List<String> sceneIds;
  final bool active;
}
