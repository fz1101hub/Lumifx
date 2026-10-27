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
  void Function(String action)? actionCallback;
  String? favouriteLabel;
  String? bedtimeLabel;

  /// Presses the notification's Stop.
  void pressStop() => stopCallback?.call();

  /// Presses the notification's (or the watch's) `favourite` or `bedtime`.
  void press(String action) => actionCallback?.call(action);

  @override
  set onStop(VoidCallback? callback) => stopCallback = callback;

  @override
  set onAction(void Function(String action)? callback) =>
      actionCallback = callback;

  @override
  Future<bool> show({
    required String title,
    required String text,
    required String stopLabel,
    required bool microphone,
    String? favouriteLabel,
    String? bedtimeLabel,
  }) async {
    this.favouriteLabel = favouriteLabel;
    this.bedtimeLabel = bedtimeLabel;
    this.title = title;
    this.text = text;
    this.microphone = microphone;
    shown = true;
    return true;
  }

  @override
  Future<void> hide() async => shown = false;
}
