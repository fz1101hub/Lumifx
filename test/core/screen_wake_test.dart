import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/screen_wake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one holder letting go keeps the screen on for the others', () async {
    const playback = WakelockScreenWake();
    const panel = WakelockScreenWake(holder: 'wall_panel');
    await panel.keepOn(true);
    await playback.keepOn(true);
    // Pause in the mini-player under the wall panel.
    await playback.keepOn(false);
    expect(WakelockScreenWake.isHeld, isTrue);
    await playback.keepOn(false);
    expect(WakelockScreenWake.isHeld, isTrue, reason: 'not counted twice');
    await panel.keepOn(false);
    expect(WakelockScreenWake.isHeld, isFalse);
  });
}
