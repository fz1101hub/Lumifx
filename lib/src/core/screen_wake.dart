import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while an effect plays: when the phone locks, the app
/// is suspended and can no longer drive the lights.
abstract interface class ScreenWake {
  Future<void> keepOn(bool on);
}

/// The phone's one keep-screen-on switch, shared: the screen stays on
/// while any [holder] (playback, the wall panel, the night light) wants
/// it, so one letting go does not turn it off under another.
class WakelockScreenWake implements ScreenWake {
  const WakelockScreenWake({this.holder = 'playback'});

  final String holder;

  static final _holders = <String>{};

  /// Whether anyone wants the screen on now.
  @visibleForTesting
  static bool get isHeld => _holders.isNotEmpty;

  @override
  Future<void> keepOn(bool on) async {
    if (on) {
      _holders.add(holder);
    } else {
      _holders.remove(holder);
    }
    try {
      await WakelockPlus.toggle(enable: _holders.isNotEmpty);
    } on Object {
      // Not fatal: the effect still plays while the screen is on.
    }
  }
}

class NoScreenWake implements ScreenWake {
  const NoScreenWake();

  @override
  Future<void> keepOn(bool on) async {}
}
