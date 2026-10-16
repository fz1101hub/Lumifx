import 'package:flutter/foundation.dart';
import 'package:lumifx/src/core/background_playback.dart';

class FakeBackgroundPlayback implements BackgroundPlayback {
  FakeBackgroundPlayback({this.isSupported = true});

  @override
  final bool isSupported;

  String? title;
  String? text;
  bool microphone = false;
  bool shown = false;
  VoidCallback? stopCallback;

  /// Presses the notification's Stop.
  void pressStop() => stopCallback?.call();

  @override
  set onStop(VoidCallback? callback) => stopCallback = callback;

  @override
  Future<bool> show({
    required String title,
    required String text,
    required String stopLabel,
    required bool microphone,
  }) async {
    this.title = title;
    this.text = text;
    this.microphone = microphone;
    shown = true;
    return true;
  }

  @override
  Future<void> hide() async => shown = false;
}
