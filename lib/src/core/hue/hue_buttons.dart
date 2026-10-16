import 'dart:convert';

/// A Hue switch, dimmer or smart button with its buttons.
class HueButtonDevice {
  const HueButtonDevice({
    required this.id,
    required this.name,
    required this.buttons,
  });

  final String id;
  final String name;

  /// In the order printed on the device (1 = top).
  final List<HueButton> buttons;
}

/// One button of a [HueButtonDevice].
class HueButton {
  const HueButton({required this.id, required this.number});

  /// The `button` resource's id: what the event stream reports.
  final String id;

  /// 1 to 4 on dimmers and tap switches, 1 on a smart button.
  final int number;
}

/// A press reported by the bridge's event stream.
class HueButtonEvent {
  const HueButtonEvent({required this.buttonId, required this.event});

  final String buttonId;

  /// `initial_press`, `repeat`, `short_release`, `long_press`,
  /// `long_release`...
  final String event;

  /// A finished short press: what LumiFX reacts to, once per press.
  bool get isShortPress => event == 'short_release';
}

/// The devices with buttons, from the bridge's `button` and `device`
/// resources.
List<HueButtonDevice> buttonDevicesOf(
  List<Map<String, Object?>> buttons,
  List<Map<String, Object?>> devices,
) {
  final names = <String, String>{
    for (final device in devices)
      if (device['id'] case final String id)
        id: switch (device['metadata']) {
          {'name': final String name} => name,
          _ => 'Hue switch',
        },
  };
  final byDevice = <String, List<HueButton>>{};
  for (final button in buttons) {
    final id = button['id'];
    final owner = button['owner'];
    final device = owner is Map ? owner['rid'] : null;
    final metadata = button['metadata'];
    final number = metadata is Map ? metadata['control_id'] : null;
    if (id is String && device is String) {
      (byDevice[device] ??= []).add(
        HueButton(id: id, number: number is int ? number : 1),
      );
    }
  }
  return [
    for (final MapEntry(key: device, value: list) in byDevice.entries)
      HueButtonDevice(
        id: device,
        name: names[device] ?? 'Hue switch',
        buttons: list..sort((a, b) => a.number.compareTo(b.number)),
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// The button presses in one `data:` line of the event stream (a JSON list
/// of messages, each with a list of changed resources). Anything else is
/// skipped.
List<HueButtonEvent> buttonEventsOf(String data) {
  final Object? messages;
  try {
    messages = jsonDecode(data);
  } on FormatException {
    return const [];
  }
  if (messages is! List) {
    return const [];
  }
  return [
    for (final message in messages)
      if (message is Map && message['data'] is List)
        for (final resource in message['data'] as List)
          if (resource is Map &&
              resource['type'] == 'button' &&
              resource['id'] is String)
            if (_eventOf(resource['button']) case final String event)
              HueButtonEvent(buttonId: resource['id'] as String, event: event),
  ];
}

String? _eventOf(Object? button) {
  if (button is! Map) {
    return null;
  }
  // Newer firmware reports `button_report`, older `last_event`.
  final report = button['button_report'];
  if (report is Map && report['event'] is String) {
    return report['event'] as String;
  }
  final last = button['last_event'];
  return last is String ? last : null;
}
