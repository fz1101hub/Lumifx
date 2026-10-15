import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while an effect plays: when the phone locks, the app
/// is suspended and can no longer drive the lights.
abstract interface class ScreenWake {
  Future<void> keepOn(bool on);
}

class WakelockScreenWake implements ScreenWake {
  const WakelockScreenWake();

  @override
  Future<void> keepOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
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
