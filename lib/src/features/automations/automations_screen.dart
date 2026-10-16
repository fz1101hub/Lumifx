import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_automations.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_schedules.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'automation_editor.dart';
import 'ok_to_wake_editor.dart';

/// Wake-up and bedtime routines stored on the bridge: they run at their
/// time even with the phone off.
class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  List<HueAutomation>? _automations;
  List<HueEffectSchedule>? _schedules;
  List<HueOkToWake>? _okToWake;
  Object? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_automations == null && !_loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final client = AppScope.of(context).bridge.client;
    if (client == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final automations = await client.fetchAutomations();
      // The older API may be switched off on some bridges: the routines
      // still show.
      final schedules = await client
          .fetchEffectSchedules()
          .catchError((Object _) => const <HueEffectSchedule>[]);
      final okToWake = await client
          .fetchOkToWake()
          .catchError((Object _) => const <HueOkToWake>[]);
      if (mounted) {
        setState(() {
          _automations = automations;
          _schedules = schedules;
          _okToWake = okToWake;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() command) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await command();
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.couldNotUpdateRoutine(describeError(l10n, error))),
        ));
    }
    await _load();
  }

  Future<void> _delete(HueAutomation automation) async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoutineQuestion(automation.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && client != null) {
      await _run(() => client.deleteAutomation(automation.id));
    }
  }

  Future<void> _deleteSchedule(HueEffectSchedule schedule) async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoutineQuestion(schedule.name)),
        content: Text(l10n.deleteScheduleDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && client != null) {
      await _run(() => client.deleteEffectSchedule(schedule));
    }
  }

  Future<void> _createOkToWake() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OkToWakeEditor()),
    );
    if (created ?? false) {
      await _load();
    }
  }

  Future<void> _deleteOkToWake(HueOkToWake light) async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoutineQuestion(light.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && client != null) {
      await _run(() => client.deleteOkToWake(light));
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AutomationEditor()),
    );
    if (created ?? false) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final home = scope.bridge.home;
    final client = scope.bridge.client;
    final automations = _automations;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routines)),
      floatingActionButton: client == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_alarm),
              label: Text(l10n.newRoutine),
            ),
      body: client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pageInsets(bottom: 96),
                children: [
                  Text(l10n.routinesDescription,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  if (_loading && automations == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    Text(
                      l10n.couldNotLoadRoutines(describeError(l10n, _error!)),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  if (automations != null && automations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.noRoutinesYet),
                    ),
                  for (final automation in automations ?? const [])
                    Card(
                      key: ValueKey(automation.id),
                      child: ListTile(
                        leading: Icon(
                          automation.kind == HueAutomationKind.wakeUp
                              ? Icons.wb_twilight
                              : Icons.bedtime_outlined,
                        ),
                        title: Text(automation.name.isEmpty
                            ? routineKindName(l10n, automation.kind)
                            : automation.name),
                        subtitle:
                            Text(describeRoutine(context, automation, home)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: automation.enabled,
                              onChanged: (value) => _run(() => client
                                  .setAutomationEnabled(automation.id, value)),
                            ),
                            IconButton(
                              tooltip: l10n.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(automation),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_okToWake case final lights?) ...[
                    const SizedBox(height: 24),
                    Text(l10n.okToWake, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l10n.okToWakeDescription,
                        style: theme.textTheme.bodySmall),
                    for (final light in lights)
                      Card(
                        key: ValueKey('ok-${light.wakeId}'),
                        child: ListTile(
                          leading: const Icon(Icons.traffic_outlined),
                          title: Text(light.name),
                          subtitle:
                              Text(describeOkToWake(context, light, home)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: light.enabled,
                                onChanged: (value) => _run(() =>
                                    client.setOkToWakeEnabled(light, value)),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteOkToWake(light),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _createOkToWake,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.newOkToWake),
                      ),
                    ),
                  ],
                  if (_schedules case final schedules?) ...[
                    const SizedBox(height: 24),
                    Text(l10n.scheduledEffects,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (schedules.isEmpty)
                      Text(l10n.noScheduledEffects,
                          style: theme.textTheme.bodySmall),
                    for (final schedule in schedules)
                      Card(
                        key: ValueKey('schedule-${schedule.id}'),
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(schedule.name),
                          subtitle:
                              Text(describeSchedule(context, schedule, home)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: schedule.enabled,
                                onChanged: (value) => _run(() => client
                                    .setEffectScheduleEnabled(schedule, value)),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteSchedule(schedule),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// "Amber from 19:30, green at 07:00 · Mon, Tue · Kids' room".
String describeOkToWake(
  BuildContext context,
  HueOkToWake light,
  HueHome? home,
) {
  final l10n = context.l10n;
  final material = MaterialLocalizations.of(context);
  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
  String time(int hour, int minute) => material.formatTimeOfDay(
        TimeOfDay(hour: hour, minute: minute),
        alwaysUse24HourFormat: h24,
      );
  final room =
      home?.groups.where((g) => g.idV1 == light.groupId).firstOrNull?.name;
  return [
    l10n.okToWakeSummary(
      time(light.nightHour, light.nightMinute),
      time(light.wakeHour, light.wakeMinute),
    ),
    describeDays(context, light.mornings),
    if (room != null) room,
  ].join(' · ');
}

/// "20:00 · Every day · Living room · until 22:00".
String describeSchedule(
  BuildContext context,
  HueEffectSchedule schedule,
  HueHome? home,
) {
  final l10n = context.l10n;
  final material = MaterialLocalizations.of(context);
  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
  String time(int hour, int minute) => material.formatTimeOfDay(
        TimeOfDay(hour: hour, minute: minute),
        alwaysUse24HourFormat: h24,
      );
  final room =
      home?.groups.where((g) => g.idV1 == schedule.groupId).firstOrNull?.name;
  final stopHour = schedule.stopHour;
  final stopMinute = schedule.stopMinute;
  return [
    time(schedule.hour, schedule.minute),
    describeDays(context, schedule.days),
    if (room != null) room,
    if (stopHour != null && stopMinute != null)
      l10n.scheduleUntil(time(stopHour, stopMinute)),
  ].join(' · ');
}

String routineKindName(AppLocalizations l10n, HueAutomationKind kind) =>
    switch (kind) {
      HueAutomationKind.wakeUp => l10n.routineWakeUp,
      HueAutomationKind.goToSleep => l10n.routineGoToSleep,
    };

/// "07:00 · Mon, Tue · Bedroom · 30 min", in the phone's language.
String describeRoutine(
  BuildContext context,
  HueAutomation automation,
  HueHome? home,
) {
  final l10n = context.l10n;
  final material = MaterialLocalizations.of(context);
  final hour = automation.hour;
  final minute = automation.minute;
  final rooms = [
    for (final id in automation.groupIds)
      if (home?.groups.where((g) => g.id == id).firstOrNull case final g?)
        g.name,
  ];
  final fade = automation.fade;
  return [
    if (hour != null && minute != null)
      material.formatTimeOfDay(
        TimeOfDay(hour: hour, minute: minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    describeDays(context, automation.days),
    if (rooms.isNotEmpty) rooms.join(', '),
    if (fade != null) l10n.sleepTimerMinutes(fade.inMinutes),
  ].join(' · ');
}

/// The days as short names, Monday first, or "Every day" / "Once".
String describeDays(BuildContext context, List<int> days) {
  final l10n = context.l10n;
  if (days.isEmpty) {
    return l10n.routineOnce;
  }
  if (days.length == 7) {
    return l10n.routineEveryDay;
  }
  return [for (final d in days) weekdayName(context, d)].join(', ');
}

/// Short name of day [index] (0 = Monday), in the app's language.
String weekdayName(BuildContext context, int index) {
  // 2024-01-01 was a Monday.
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.E(locale).format(DateTime(2024, 1, 1 + index));
}
