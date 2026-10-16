import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'audio_input.dart';

/// The audio this phone itself is playing (Spotify, YouTube, games...),
/// on Android 10 and later, through Android's playback capture.
///
/// Android asks the user to allow "screen capture" the first time (and,
/// from Android 14, on every start); only the sound is taken, nothing is
/// recorded. The capture runs in a foreground service with a
/// notification (see `PhoneAudioCaptureService.kt`). Apps that opt out
/// of capture stay silent here, which is Android's rule, not ours.
class PhoneAudioInput implements AudioInput {
  PhoneAudioInput({
    @visibleForTesting MethodChannel? methods,
    @visibleForTesting EventChannel? pcm,
    @visibleForTesting Future<bool> Function()? microphonePermission,
  })  : _methods = methods ?? _defaultMethods,
        _pcm = pcm ?? _defaultPcm,
        _microphonePermission =
            microphonePermission ?? _requestMicrophonePermission;

  static const _defaultMethods = MethodChannel('com.lumifx/phone_audio');
  static const _defaultPcm = EventChannel('com.lumifx/phone_audio/pcm');

  final MethodChannel _methods;
  final EventChannel _pcm;
  final Future<bool> Function() _microphonePermission;
  final _capturing = StreamController<bool>.broadcast();
  StreamSubscription<Object?>? _events;
  StreamController<Uint8List>? _out;

  /// The input, or null where the platform cannot capture its own audio
  /// (iOS, Android before 10).
  static Future<PhoneAudioInput?> ifSupported({
    @visibleForTesting MethodChannel? methods,
    @visibleForTesting bool? isAndroid,
  }) async {
    if (!(isAndroid ?? Platform.isAndroid)) {
      return null;
    }
    try {
      final supported =
          await (methods ?? _defaultMethods).invokeMethod<bool>('isSupported');
      return supported == true ? PhoneAudioInput(methods: methods) : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Playback capture needs the microphone permission too (Android treats
  /// it as a recording), asked through the same plugin as the microphone.
  static Future<bool> _requestMicrophonePermission() async {
    final recorder = AudioRecorder();
    try {
      return await recorder.hasPermission();
    } finally {
      await recorder.dispose();
    }
  }

  @override
  int get sampleRate => 44100;

  @override
  Stream<bool> get capturing => _capturing.stream;

  /// Microphone permission, then Android's capture consent dialog.
  @override
  Future<bool> requestPermission() async {
    if (!await _microphonePermission()) {
      return false;
    }
    return await _methods.invokeMethod<bool>('requestConsent') ?? false;
  }

  @override
  Future<Stream<Uint8List>> start() async {
    await _events?.cancel();
    final out = _out = StreamController<Uint8List>();
    // Listen before starting, so the first chunks are not lost.
    _events = _pcm.receiveBroadcastStream().listen(
      (chunk) {
        if (chunk is Uint8List && !out.isClosed) {
          out.add(chunk);
        }
      },
      onError: (Object error) {
        _ended(out);
        if (!out.isClosed) {
          out.addError(error);
        }
      },
      onDone: () => _ended(out),
    );
    try {
      await _methods.invokeMethod<void>('start');
    } on Object {
      await _events?.cancel();
      _events = null;
      _out = null;
      rethrow;
    }
    _capturing.add(true);
    return out.stream;
  }

  /// The service stopped on its own.
  void _ended(StreamController<Uint8List> out) {
    if (identical(_out, out)) {
      _out = null;
      if (!_capturing.isClosed) {
        _capturing.add(false);
      }
    }
    if (!out.isClosed) {
      unawaited(out.close());
    }
  }

  @override
  Future<void> stop() async {
    final events = _events;
    _events = null;
    await events?.cancel();
    final out = _out;
    _out = null;
    if (out != null && !out.isClosed) {
      unawaited(out.close());
    }
    try {
      await _methods.invokeMethod<void>('stop');
    } finally {
      if (!_capturing.isClosed) {
        _capturing.add(false);
      }
    }
  }
}
