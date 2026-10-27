import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/calendar/calendar_source.dart';
import '../../core/color/light_color.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../learn/colour_words.dart';
import 'calendar_lights.dart';

/// The lights before appointments: on or off, which room, how long before
/// and which colour, and what is coming up.
class CalendarLightsScreen extends StatefulWidget {
  const CalendarLightsScreen({super.key});

  @override
  State<CalendarLightsScreen> createState() => _CalendarLightsScreenState();
}

class _CalendarLightsScreenState extends State<CalendarLightsScreen> {
  List<CalendarEvent>? _events;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_loadEvents());
    }
  }

  Future<void> _loadEvents() async {
    final scope = AppScope.of(context);
    if (!await scope.calendar.hasAccess()) {
      return;
    }
    final now = scope.clock();
    final events =
        await scope.calendar.events(now, now.add(const Duration(days: 1)));
    if (mounted) {
      setState(() => _events = events);
    }
  }

  List<HueGroup> get _rooms => [
        for (final room
            in AppScope.of(context).bridge.home?.rooms ?? const <HueGroup>[])
          if (room.idV1 != null) room,
      ];

  Future<void> _switch(bool on) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      await scope.preferences.setCalendarLights(null);
      return;
    }
    final rooms = _rooms;
    if (rooms.isEmpty) {
      return;
    }
    if (!await scope.calendar.requestAccess()) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.calendarLightsDenied)));
      return;
    }
    await scope.preferences
        .setCalendarLights(CalendarLightsSettings(groupId: rooms.first.idV1!));
    await _loadEvents();
  }

  Future<void> _update() async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final count = await scope.calendarLights?.sync(force: true);
    await _loadEvents();
    if (count != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.calendarLightsSynced(count))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarLights)),
      body: scope.bridge.client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : ListenableBuilder(
              listenable: preferences,
              builder: (context, _) {
                final settings = preferences.calendarLights;
                final events = _events;
                return ListView(
                  padding: context.pageInsets(),
                  children: [
                    Text(l10n.calendarLightsDescription,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.calendarLightsOn),
                      value: settings != null,
                      onChanged: scope.calendar.isSupported ? _switch : null,
                    ),
                    if (settings != null) ...[
                      Text(l10n.lightReminderRoom,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final room in _rooms)
                            ChoiceChip(
                              label: Text(room.name),
                              selected: settings.groupId == room.idV1,
                              onSelected: (_) => preferences.setCalendarLights(
                                  settings.copyWith(groupId: room.idV1)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.calendarLightsBefore,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final minutes
                              in CalendarLightsSettings.minuteChoices)
                            ChoiceChip(
                              label: Text(l10n.calendarLightsMinutes(minutes)),
                              selected: settings.minutesBefore == minutes,
                              onSelected: (_) => preferences.setCalendarLights(
                                  settings.copyWith(minutesBefore: minutes)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.lightReminderColour,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final color
                              in CalendarLightsSettings.colorChoices)
                            Semantics(
                              button: true,
                              selected: settings.color == color,
                              label: LearnColour.values
                                  .firstWhere((c) => c.hex == color)
                                  .word(Localizations.localeOf(context)
                                      .languageCode),
                              excludeSemantics: true,
                              child: InkResponse(
                                onTap: () => preferences.setCalendarLights(
                                    settings.copyWith(color: color)),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      LightColor.fromHex(color).toColor(),
                                  child: settings.color == color
                                      ? const Icon(Icons.check,
                                          color: Colors.black87)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.calendarLightsNext,
                                style: theme.textTheme.titleMedium),
                          ),
                          TextButton.icon(
                            onPressed: _update,
                            icon: const Icon(Icons.sync),
                            label: Text(l10n.calendarLightsUpdate),
                          ),
                        ],
                      ),
                      if (events == null)
                        const LinearProgressIndicator()
                      else if (events.every((e) => e.allDay))
                        Text(l10n.calendarLightsNone,
                            style: theme.textTheme.bodyMedium)
                      else
                        for (final event in events)
                          if (!event.allDay)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_outlined),
                              title: Text(event.title),
                              subtitle: Text(localizations.formatTimeOfDay(
                                  TimeOfDay.fromDateTime(event.start),
                                  alwaysUse24HourFormat: h24)),
                            ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
