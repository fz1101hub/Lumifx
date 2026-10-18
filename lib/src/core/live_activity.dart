import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the lock screen shows while an effect plays.
class LiveActivityState {
  const LiveActivityState({
    required this.effect,
    required this.room,
    required this.playing,
    required this.colors,
    required this.stopLabel,
  });

  final String effect;
  final String room;
  final bool playing;

  /// The effect's colours, as ARGB.
  final List<int> colors;

  final String stopLabel;

  Map<String, Object?> toJson() => {
        'effect': effect,
        'room': room,
        'playing': playing,
        'colors': colors,
        'stopLabel': stopLabel,
      };
}

/// The effect playing on the iPhone's lock screen and in the Dynamic
/// Island, with a Stop button: a Live Activity (iOS 16.1+), drawn by the
/// widget extension (see docs/IOS_WIDGET.md). Elsewhere it does nothing.
abstract interface class LiveActivity {
  bool get isSupported;

  /// Shows [state], or updates what is shown; false when iOS refused
  /// (Live Activities switched off, or too old a system).
  Future<bool> update(LiveActivityState state);

  Future<void> end();
}

class NoLiveActivity implements LiveActivity {
  const NoLiveActivity();

  @override
  bool get isSupported => false;

  @override
  Future<bool> update(LiveActivityState state) async => false;

  @override
  Future<void> end() async {}
}

class ChannelLiveActivity implements LiveActivity {
  ChannelLiveActivity({@visibleForTesting bool? supported})
      : isSupported = supported ?? Platform.isIOS;

  static const _channel = MethodChannel('com.lumifx/live_activity');

  @override
  final bool isSupported;

  @override
  Future<bool> update(LiveActivityState state) async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('update', state.toJson()) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> end() async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('end');
    } on PlatformException {
      // Already gone.
    } on MissingPluginException {
      // No Live Activities here.
    }
  }
}
