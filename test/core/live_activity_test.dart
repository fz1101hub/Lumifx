import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/live_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.lumifx/live_activity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const state = LiveActivityState(
    effect: 'Ocean',
    room: 'Living room',
    playing: true,
    colors: [0xFF0B3C5D, 0xFF1E6F9F],
    stopLabel: 'Stop',
  );

  test('shows, updates and ends the Live Activity over the channel', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'update' ? true : null;
    });
    final live = ChannelLiveActivity(supported: true);
    expect(await live.update(state), isTrue);
    await live.end();
    expect([for (final c in calls) c.method], ['update', 'end']);
    expect(calls.first.arguments, {
      'effect': 'Ocean',
      'room': 'Living room',
      'playing': true,
      'colors': [0xFF0B3C5D, 0xFF1E6F9F],
      'stopLabel': 'Stop',
    });
  });

  test('elsewhere, or refused, it is quietly not there', () async {
    expect(await ChannelLiveActivity(supported: false).update(state), isFalse);
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'off'));
    final live = ChannelLiveActivity(supported: true);
    expect(await live.update(state), isFalse);
    await live.end();
  });
}
