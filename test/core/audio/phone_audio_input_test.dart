import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/audio/phone_audio_input.dart';

/// Stands in for `PhoneAudioCapture.kt`: records the calls and plays the
/// PCM chunks it is given.
class _FakeNative {
  _FakeNative({this.supported = true, this.consent = true});

  final bool supported;
  final bool consent;
  final calls = <String>[];
  MockStreamHandlerEventSink? sink;
  final methods = const MethodChannel('test.phone_audio');
  final pcm = const EventChannel('test.phone_audio/pcm');

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isSupported':
          return supported;
        case 'requestConsent':
          return consent;
        case 'start':
          if (!consent) {
            throw PlatformException(code: 'no_consent');
          }
          return null;
        case 'stop':
          return null;
      }
      throw MissingPluginException();
    });
    messenger.setMockStreamHandler(
      pcm,
      MockStreamHandler.inline(
        onListen: (_, events) => sink = events,
        onCancel: (_) => sink = null,
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(pcm, null);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only offered on Android 10+', () async {
    final native = _FakeNative()..install();
    expect(
      await PhoneAudioInput.ifSupported(
          methods: native.methods, isAndroid: false),
      isNull,
    );
    expect(native.calls, isEmpty);
    expect(
      await PhoneAudioInput.ifSupported(
          methods: native.methods, isAndroid: true),
      isNotNull,
    );
    final old = _FakeNative(supported: false)..install();
    expect(
      await PhoneAudioInput.ifSupported(methods: old.methods, isAndroid: true),
      isNull,
    );
    // No plugin at all (a platform without the activity code).
    expect(
      await PhoneAudioInput.ifSupported(
        methods: const MethodChannel('test.missing'),
        isAndroid: true,
      ),
      isNull,
    );
  });

  test('asks for the microphone, then consent, then streams the capture',
      () async {
    final native = _FakeNative()..install();
    var microphoneAsked = 0;
    final input = PhoneAudioInput(
      methods: native.methods,
      pcm: native.pcm,
      microphonePermission: () async {
        microphoneAsked++;
        return true;
      },
    );
    final states = <bool>[];
    input.capturing.listen(states.add);

    expect(await input.requestPermission(), isTrue);
    expect(microphoneAsked, 1);
    expect(native.calls, ['requestConsent']);

    final stream = await input.start();
    expect(native.calls, ['requestConsent', 'start']);
    expect(native.sink, isNotNull, reason: 'listens before starting');
    final received = <Uint8List>[];
    final done = Completer<void>();
    stream.listen(received.add, onDone: done.complete);
    native.sink!.success(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(Duration.zero);
    expect(received.single, [1, 2, 3, 4]);
    expect(states, [true]);

    // The service ended on its own: the stream ends and capture is off.
    native.sink!.endOfStream();
    await done.future;
    expect(states, [true, false]);

    await input.stop();
    expect(native.calls.last, 'stop');
  });

  test('a refused microphone never shows the consent dialog', () async {
    final native = _FakeNative()..install();
    final input = PhoneAudioInput(
      methods: native.methods,
      pcm: native.pcm,
      microphonePermission: () async => false,
    );
    expect(await input.requestPermission(), isFalse);
    expect(native.calls, isEmpty);
  });

  test('a refused consent is a denied permission, and start fails', () async {
    final native = _FakeNative(consent: false)..install();
    final input = PhoneAudioInput(
      methods: native.methods,
      pcm: native.pcm,
      microphonePermission: () async => true,
    );
    expect(await input.requestPermission(), isFalse);
    await expectLater(input.start(), throwsA(isA<PlatformException>()));
    expect(native.sink, isNull, reason: 'the listener is released');
  });

  test('stop ends the stream and the capture state', () async {
    final native = _FakeNative()..install();
    final input = PhoneAudioInput(
      methods: native.methods,
      pcm: native.pcm,
      microphonePermission: () async => true,
    );
    final states = <bool>[];
    input.capturing.listen(states.add);
    final stream = await input.start();
    final done = Completer<void>();
    stream.listen((_) {}, onDone: done.complete);
    await input.stop();
    await done.future;
    // The capture state is a broadcast stream: give it a turn to deliver.
    await Future<void>.delayed(Duration.zero);
    expect(native.sink, isNull);
    expect(states, [true, false]);
  });
}
