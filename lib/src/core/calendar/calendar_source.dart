import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An appointment in the phone's calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    this.allDay = false,
  });

  final String title;
  final DateTime start;
  final bool allDay;
}

/// The phone's calendar, read only: the lights before an appointment.
/// Only the times reach the bridge; titles stay on the phone.
abstract interface class CalendarSource {
  bool get isSupported;

  Future<bool> hasAccess();

  /// Asks for the calendar; false if refused.
  Future<bool> requestAccess();

  /// The appointments starting between [from] and [to], earliest first.
  Future<List<CalendarEvent>> events(DateTime from, DateTime to);
}

class NoCalendar implements CalendarSource {
  const NoCalendar();

  @override
  bool get isSupported => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<List<CalendarEvent>> events(DateTime from, DateTime to) async =>
      const [];
}

/// `com.lumifx/calendar`: CalendarChannel.kt on Android, CalendarBridge in
/// AppDelegate.swift on iOS.
class ChannelCalendar implements CalendarSource {
  ChannelCalendar({@visibleForTesting bool? supported})
      : isSupported = supported ?? (Platform.isAndroid || Platform.isIOS);

  static const _channel = MethodChannel('com.lumifx/calendar');

  @override
  final bool isSupported;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Calendar: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> hasAccess() async => await _invoke<bool>('hasAccess') ?? false;

  @override
  Future<bool> requestAccess() async =>
      await _invoke<bool>('requestAccess') ?? false;

  @override
  Future<List<CalendarEvent>> events(DateTime from, DateTime to) async {
    final found = await _invoke<List<Object?>>('events', {
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
    });
    return [
      for (final item in found ?? const [])
        if (item is Map && item['start'] is int)
          CalendarEvent(
            title: '${item['title'] ?? ''}',
            start: DateTime.fromMillisecondsSinceEpoch(item['start'] as int),
            allDay: item['allDay'] == true,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }
}
