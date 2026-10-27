import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'automations_calendar.dart';

/// The week of everything the bridge does by itself, a day at a time,
/// each switched on and off from here.
class AutomationsCalendarScreen extends StatefulWidget {
  const AutomationsCalendarScreen({super.key});

  @override
  State<AutomationsCalendarScreen> createState() =>
      _AutomationsCalendarScreenState();
}

class _AutomationsCalendarScreenState extends State<AutomationsCalendarScreen> {
  List<CalendarEntry>? _entries;
  int? _day;
  var _busy = false;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final client = AppScope.of(context).bridge.client;
    if (client == null) {
      return;
    }
    final entries = await loadCalendar(client);
    if (mounted) {
      setState(() => _entries = entries);
    }
  }

  Future<void> _toggle(CalendarEntry entry, bool enabled) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await entry.setEnabled(enabled);
      await _load();
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error)))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static IconData _icon(CalendarKind kind) => switch (kind) {
        CalendarKind.effect => Icons.auto_awesome,
        CalendarKind.okToWake => Icons.traffic_outlined,
        CalendarKind.wakeUp => Icons.wb_sunny_outlined,
        CalendarKind.goToSleep => Icons.bedtime_outlined,
        CalendarKind.away => Icons.flight_takeoff,
        CalendarKind.reminder => Icons.notifications_none,
        CalendarKind.nightOff => Icons.nights_stay_outlined,
      };

  static String _kindName(AppLocalizations l10n, CalendarKind kind) =>
      switch (kind) {
        CalendarKind.effect => l10n.calendarEffect,
        CalendarKind.okToWake => l10n.okToWake,
        CalendarKind.wakeUp => l10n.routineWakeUp,
        CalendarKind.goToSleep => l10n.routineGoToSleep,
        CalendarKind.away => l10n.awayMode,
        CalendarKind.reminder => l10n.lightReminders,
        CalendarKind.nightOff => l10n.nightOff,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    final day = _day ?? scope.clock().weekday - 1;
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.automationsCalendar)),
      body: client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pageInsets(),
                children: [
                  Text(l10n.automationsCalendarDescription,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var d = 0; d < 7; d++)
                        ChoiceChip(
                          // 1 January 2024 was a Monday.
                          label: Text(DateFormat.E(l10n.localeName)
                              .format(DateTime(2024, 1, 1 + d))),
                          selected: day == d,
                          onSelected: (_) => setState(() => _day = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (entries == null)
                    const LinearProgressIndicator()
                  else ...[
                    if (entriesOn(entries, day) case final today
                        when today.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(l10n.calendarNothing,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge),
                      )
                    else
                      for (final entry in entriesOn(entries, day))
                        _tile(context, entry),
                    if (onceEntries(entries) case final once
                        when once.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(l10n.calendarOnce,
                          style: theme.textTheme.titleMedium),
                      for (final entry in once) _tile(context, entry),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, CalendarEntry entry) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final names = {
      for (final group in scope.bridge.home?.groups ?? const <HueGroup>[]) ...{
        group.id: group.name,
        if (group.idV1 case final v1?) v1: group.name,
      },
    };
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: entry.hour, minute: entry.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    final kind = _kindName(l10n, entry.kind);
    final places = [for (final p in entry.places) names[p] ?? p].join(', ');
    return Card(
      child: SwitchListTile(
        secondary: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon(entry.kind)),
            Text(time, style: theme.textTheme.labelSmall),
          ],
        ),
        title: Text(entry.title.isEmpty ? kind : entry.title),
        subtitle: Text([
          if (entry.title.isNotEmpty) kind,
          if (places.isNotEmpty) places,
        ].join(' · ')),
        value: entry.enabled,
        onChanged: _busy ? null : (on) => _toggle(entry, on),
      ),
    );
  }
}
