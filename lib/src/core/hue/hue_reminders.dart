/// A room that takes a colour at set times, as a reminder: yellow on the
/// evening the plastic goes out, purple for the medicine, green for the
/// plants. It breathes for a few seconds in that colour, then stays, and
/// optionally switches off a while later. Kept as the bridge's own
/// schedules, so it works with the phone off.
class HueLightReminder {
  const HueLightReminder({
    required this.token,
    required this.name,
    required this.groupId,
    required this.hour,
    required this.minute,
    required this.days,
    required this.color,
    required this.offAfterMinutes,
    required this.enabled,
    required this.scheduleIds,
  });

  final String token;
  final String name;

  /// The v1 id of the room.
  final String groupId;
  final int hour;
  final int minute;

  /// 0 (Monday) to 6.
  final List<int> days;

  /// `#RRGGBB`.
  final String color;

  /// The room switches off this long after, or stays on (null).
  final int? offAfterMinutes;
  final bool enabled;
  final List<String> scheduleIds;
}

class HueLightReminderDraft {
  const HueLightReminderDraft({
    required this.name,
    required this.groupId,
    required this.hour,
    required this.minute,
    required this.days,
    required this.color,
    this.offAfterMinutes,
  });

  final String name;
  final String groupId;
  final int hour;
  final int minute;
  final List<int> days;
  final String color;
  final int? offAfterMinutes;

  static const offChoices = [5, 15, 30, 60];
  static const brightness = 200;

  /// Colours that say something at a glance; the names are the app's.
  static const colors = [
    '#FFD23F', // plastic, yellow
    '#3D7BFF', // paper, blue
    '#3DDC84', // glass, plants
    '#A0522D', // organic, brown
    '#B0B0B0', // general waste, grey
    '#B388FF', // medicine, purple
    '#FF4D4D', // something important, red
    '#FF8A3D', // orange
  ];
}

/// At night, chosen rooms fade out and switch off, in case a light was
/// left on: every night at a set time, kept on the bridge. A room already
/// off stays off.
class HueNightOff {
  const HueNightOff({
    required this.token,
    required this.groupIds,
    required this.hour,
    required this.minute,
    required this.fadeMinutes,
    required this.enabled,
    required this.scheduleIds,
  });

  final String token;
  final List<String> groupIds;
  final int hour;
  final int minute;
  final int fadeMinutes;
  final bool enabled;
  final List<String> scheduleIds;
}

class HueNightOffDraft {
  const HueNightOffDraft({
    required this.groupIds,
    required this.hour,
    required this.minute,
    this.fadeMinutes = 5,
  });

  final List<String> groupIds;
  final int hour;
  final int minute;
  final int fadeMinutes;

  static const fadeChoices = [1, 5, 10];
  static const maxRooms = 8;
}
