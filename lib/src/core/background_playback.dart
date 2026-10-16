import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps effects playing with the screen off. Android runs a foreground
/// service with a notification (see PlaybackService.kt); iOS has no such
/// thing, so there playback stops when the app leaves the screen.
abstract interface class BackgroundPlayback {
  bool get isSupported;

  /// Shows (or updates) the notification and keeps the app running.
  /// False when the platform refused.
  Future<bool> show({
    required String title,
    required String text,
    required String stopLabel,
    required bool microphone,
  });

  Future<void> hide();

  /// Called when the notification's Stop is pressed.
  set onStop(VoidCallback? callback);
}

class ChannelBackgroundPlayback implements BackgroundPlayback {
  ChannelBackgroundPlayback({@visibleForTesting bool? supported})
      : isSupported = supported ?? Platform.isAndroid {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stop') {
        _onStop?.call();
      }
    });
  }

  static const _channel = MethodChannel('com.lumifx/background');

  @override
  final bool isSupported;

  VoidCallback? _onStop;

  @override
  set onStop(VoidCallback? callback) => _onStop = callback;

  @override
  Future<bool> show({
    required String title,
    required String text,
    required String stopLabel,
    required bool microphone,
  }) async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('show', {
            'title': title,
            'text': text,
            'stop': stopLabel,
            'microphone': microphone,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> hide() async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('hide');
    } on PlatformException {
      // Already gone.
    } on MissingPluginException {
      // No service on this platform.
    }
  }
}

class NoBackgroundPlayback implements BackgroundPlayback {
  const NoBackgroundPlayback();

  @override
  bool get isSupported => false;

  @override
  Future<bool> show({
    required String title,
    required String text,
    required String stopLabel,
    required bool microphone,
  }) async =>
      false;

  @override
  Future<void> hide() async {}

  @override
  set onStop(VoidCallback? callback) {}
}
