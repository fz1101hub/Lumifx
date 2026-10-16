import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_house.dart';
import '../../core/hue/hue_models.dart';
import '../automations/automations_screen.dart';
import '../common/app_text.dart';
import '../common/layout.dart';

/// Routines for the house that the bridge runs by itself: the lights
/// looking lived-in while away, a night path on a motion sensor, and
/// whites that follow the day.
class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  List<HueAwayMode>? _away;
  List<HueNightPath>? _paths;
  List<HueMotionSensor> _sensors = const [];
  List<HueNaturalLight>? _natural;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_away == null && !_loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    if (client == null) {
      return;
    }
    setState(() => _loading = true);
    final ids = scope.preferences.naturalLightIds;
    final results = await Future.wait<Object>([
      client.fetchAwayModes().catchError((Object _) => <HueAwayMode>[]),
      client.fetchNightPaths().catchError((Object _) => <HueNightPath>[]),
      client.fetchMotionSensors().catchError((Object _) => <HueMotionSensor>[]),
      client
          .fetchNaturalLights(ids)
          .catchError((Object _) => <HueNaturalLight>[]),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _away = results[0] as List<HueAwayMode>;
      _paths = results[1] as List<HueNightPath>;
      _sensors = results[2] as List<HueMotionSensor>;
      _natural = results[3] as List<HueNaturalLight>;
      _loading = false;
    });
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

  Future<bool> _confirmDelete(String name) async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteRoutineQuestion(name)),
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
        ) ==
        true;
  }

  Future<void> _newNaturalLight() async {
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    final home = scope.bridge.home;
    if (client == null || home == null) {
      return;
    }
    final group = await showDialog<HueGroup>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.houseChooseRoom),
        children: [
          for (final group in home.groups)
            if (group.lightIds.isNotEmpty)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(group),
                child: Text(group.name),
              ),
        ],
      ),
    );
    if (group == null || !mounted) {
      return;
    }
    await _run(() async {
      final id = await client.createNaturalLight(
        name: l10n.naturalLightName(group.name),
        group: group,
        lights: home.lights.values.toList(),
        slotNames: [
          l10n.naturalLightMorning,
          l10n.naturalLightDay,
          l10n.naturalLightAfternoon,
          l10n.naturalLightEvening,
          l10n.naturalLightNight,
        ],
      );
      await scope.preferences.addNaturalLight(id);
      await client.setSmartSceneActive(id, active: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    final groups = {
      for (final group in scope.bridge.home?.groups ?? const <HueGroup>[]) ...{
        group.id: group.name,
        if (group.idV1 case final v1?) v1: group.name
      },
    };
    final sensors = {for (final s in _sensors) s.id: s.name};
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String time(int hour, int minute) =>
        localizations.formatTimeOfDay(TimeOfDay(hour: hour, minute: minute),
            alwaysUse24HourFormat: h24);
    Widget header(IconData icon, String title, String description) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium)),
              ]),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.house)),
      body: client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pageInsets(),
                children: [
                  if (_loading && _away == null)
                    const LinearProgressIndicator(),
                  header(Icons.flight_takeoff, l10n.awayMode,
                      l10n.awayModeDescription),
                  for (final mode in _away ?? const <HueAwayMode>[])
                    Card(
                      child: SwitchListTile(
                        title: Text(mode.name),
                        subtitle: Text(l10n.awayModeSummary(
                          [for (final g in mode.groupIds) groups[g] ?? g]
                              .join(', '),
                          time(mode.onHour, mode.onMinute),
                          time(mode.offHour, mode.offMinute),
                        )),
                        value: mode.enabled,
                        onChanged: (on) =>
                            _run(() => client.setAwayModeEnabled(mode, on)),
                        secondary: IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await _confirmDelete(mode.name)) {
                              await _run(() => client.deleteAwayMode(mode));
                            }
                          },
                        ),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () async {
                        final saved = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const AwayModeEditor()),
                        );
                        if (saved == true) {
                          await _load();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.awayModeNew),
                    ),
                  ),
                  header(Icons.directions_walk, l10n.nightPath,
                      l10n.nightPathDescription),
                  for (final path in _paths ?? const <HueNightPath>[])
                    Card(
                      child: SwitchListTile(
                        title: Text(l10n.nightPathTitle(
                          sensors[path.sensorId] ?? path.sensorId,
                          groups[path.groupId] ?? path.groupId,
                        )),
                        subtitle: Text(l10n.nightPathSummary(
                          time(path.fromHour, path.fromMinute),
                          time(path.toHour, path.toMinute),
                          path.minutes,
                        )),
                        value: path.enabled,
                        onChanged: (on) =>
                            _run(() => client.setNightPathEnabled(path, on)),
                        secondary: IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await _confirmDelete(l10n.nightPath)) {
                              await _run(() => client.deleteNightPath(path));
                            }
                          },
                        ),
                      ),
                    ),
                  if (_away != null && _sensors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(l10n.nightPathNoSensor),
                    )
                  else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () async {
                          final saved = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NightPathEditor(sensors: _sensors),
                            ),
                          );
                          if (saved == true) {
                            await _load();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: Text(l10n.nightPathNew),
                      ),
                    ),
                  header(Icons.wb_twilight, l10n.naturalLight,
                      l10n.naturalLightDescription),
                  for (final light in _natural ?? const <HueNaturalLight>[])
                    Card(
                      child: SwitchListTile(
                        title: Text(groups[light.groupId] ?? light.name),
                        subtitle: Text(light.active
                            ? l10n.naturalLightOn
                            : l10n.naturalLightOff),
                        value: light.active,
                        onChanged: (on) =>
                            _run(() => client.setNaturalLightActive(light, on)),
                        secondary: IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await _confirmDelete(light.name)) {
                              await _run(() async {
                                await client.deleteNaturalLight(light);
                                await scope.preferences
                                    .removeNaturalLight(light.id);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _newNaturalLight,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.naturalLightNew),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A new away mode: which rooms, from when to when, which evenings.
class AwayModeEditor extends StatefulWidget {
  const AwayModeEditor({super.key});

  @override
  State<AwayModeEditor> createState() => _AwayModeEditorState();
}

class _AwayModeEditorState extends State<AwayModeEditor> {
  final _rooms = <String>[];
  TimeOfDay _on = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _off = const TimeOfDay(hour: 23, minute: 0);
  final _days = {0, 1, 2, 3, 4, 5, 6};
  bool _saving = false;

  Future<void> _save() async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    if (client == null || _rooms.isEmpty || _days.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await client.createAwayMode(HueAwayModeDraft(
        name: l10n.awayMode,
        groupIds: [..._rooms],
        onHour: _on.hour,
        onMinute: _on.minute,
        offHour: _off.hour,
        offMinute: _off.minute,
        days: _days.toList()..sort(),
      ));
      navigator.pop(true);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error))),
      ));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final groups = [
      for (final group in AppScope.of(context).bridge.home?.groups ?? const [])
        if (group.idV1 != null && group.lightIds.isNotEmpty) group,
    ];
    Future<void> pick(TimeOfDay initial, ValueChanged<TimeOfDay> set) async {
      final picked =
          await showTimePicker(context: context, initialTime: initial);
      if (picked != null) {
        setState(() => set(picked));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.awayModeNew),
        actions: [
          TextButton(
            onPressed:
                _saving || _rooms.isEmpty || _days.isEmpty ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.awayModeDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.awayModeRooms, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final group in groups)
                FilterChip(
                  label: Text(group.name),
                  selected: _rooms.contains(group.idV1),
                  onSelected: (on) => setState(() {
                    if (on && _rooms.length < HueAwayModeDraft.maxRooms) {
                      _rooms.add(group.idV1!);
                    } else {
                      _rooms.remove(group.idV1);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(l10n.awayModeOnAt),
            trailing: Text(
                localizations.formatTimeOfDay(_on, alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () => pick(_on, (t) => _on = t),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(l10n.awayModeOffAt),
            trailing: Text(
                localizations.formatTimeOfDay(_off, alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () => pick(_off, (t) => _off = t),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(weekdayName(context, d)),
                  selected: _days.contains(d),
                  onSelected: (on) =>
                      setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.awayModeHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// A new night path: which sensor, which room, the night's hours and how
/// long the light stays after the last motion.
class NightPathEditor extends StatefulWidget {
  const NightPathEditor({required this.sensors, super.key});

  final List<HueMotionSensor> sensors;

  @override
  State<NightPathEditor> createState() => _NightPathEditorState();
}

class _NightPathEditorState extends State<NightPathEditor> {
  late String? _sensor = widget.sensors.firstOrNull?.id;
  String? _room;
  TimeOfDay _from = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 7, minute: 0);
  int _minutes = 5;
  bool _saving = false;

  Future<void> _save(String room) async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    final sensor = _sensor;
    if (client == null || sensor == null) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await client.createNightPath(HueNightPathDraft(
        sensorId: sensor,
        groupId: room,
        fromHour: _from.hour,
        fromMinute: _from.minute,
        toHour: _to.hour,
        toMinute: _to.minute,
        minutes: _minutes,
      ));
      navigator.pop(true);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error))),
      ));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final groups = [
      for (final group in AppScope.of(context).bridge.home?.groups ?? const [])
        if (group.idV1 != null && group.lightIds.isNotEmpty) group,
    ];
    final room = _room ?? groups.firstOrNull?.idV1;
    Future<void> pick(TimeOfDay initial, ValueChanged<TimeOfDay> set) async {
      final picked =
          await showTimePicker(context: context, initialTime: initial);
      if (picked != null) {
        setState(() => set(picked));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nightPathNew),
        actions: [
          TextButton(
            onPressed: _saving || room == null || _sensor == null
                ? null
                : () => _save(room),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.nightPathDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _sensor,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.nightPathSensor,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final sensor in widget.sensors)
                DropdownMenuItem(value: sensor.id, child: Text(sensor.name)),
            ],
            onChanged: (id) => setState(() => _sensor = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: room,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.okToWakeRoom,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final group in groups)
                DropdownMenuItem(value: group.idV1, child: Text(group.name)),
            ],
            onChanged: (id) => setState(() => _room = id),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l10n.nightPathFrom),
            trailing: Text(
                localizations.formatTimeOfDay(_from,
                    alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () => pick(_from, (t) => _from = t),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l10n.nightPathTo),
            trailing: Text(
                localizations.formatTimeOfDay(_to, alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () => pick(_to, (t) => _to = t),
          ),
          const SizedBox(height: 8),
          Text(l10n.nightPathStays, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in HueNightPathDraft.minuteChoices)
                ChoiceChip(
                  label: Text(l10n.sleepTimerMinutes(minutes)),
                  selected: _minutes == minutes,
                  onSelected: (_) => setState(() => _minutes = minutes),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.nightPathHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
