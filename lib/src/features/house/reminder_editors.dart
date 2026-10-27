import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_reminders.dart';
import '../automations/automations_screen.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';

/// A new light reminder: what for, which room, which colour, when, on
/// which days, and whether the room switches off afterwards.
class LightReminderEditor extends StatefulWidget {
  const LightReminderEditor({super.key});

  @override
  State<LightReminderEditor> createState() => _LightReminderEditorState();
}

class _LightReminderEditorState extends State<LightReminderEditor> {
  final _name = TextEditingController();
  String? _room;
  var _color = HueLightReminderDraft.colors.first;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final _days = <int>{1};
  int? _offAfter = 30;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _room != null && _days.isNotEmpty && !_saving;

  Future<void> _save() async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    if (client == null || !_ready) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    try {
      await client.createLightReminder(HueLightReminderDraft(
        name: name.isEmpty ? l10n.lightReminders : name,
        groupId: _room!,
        hour: _time.hour,
        minute: _time.minute,
        days: _days.toList()..sort(),
        color: _color,
        offAfterMinutes: _offAfter,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lightReminderNew),
        actions: [
          TextButton(
            onPressed: _ready ? _save : null,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.lightRemindersDescription,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 32,
            decoration: InputDecoration(
              labelText: l10n.lightReminderName,
              hintText: l10n.lightReminderNameHint,
            ),
          ),
          Text(l10n.lightReminderRoom, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final group in groups)
                ChoiceChip(
                  label: Text(group.name),
                  selected: _room == group.idV1,
                  onSelected: (_) => setState(() => _room = group.idV1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.lightReminderColour, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, color) in HueLightReminderDraft.colors.indexed)
                Semantics(
                  button: true,
                  selected: _color == color,
                  label: l10n.sceneSwatch(i + 1),
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LightColor.fromHex(color).toColor(),
                        border: Border.all(
                          color: _color == color
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.outlineVariant,
                          width: _color == color ? 4 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.lightReminderTime),
            trailing: Text(
                localizations.formatTimeOfDay(_time,
                    alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) {
                setState(() => _time = picked);
              }
            },
          ),
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
          Text(l10n.lightReminderOffAfter, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final minutes in [
                ...HueLightReminderDraft.offChoices,
                null,
              ])
                ChoiceChip(
                  label: Text(minutes == null
                      ? l10n.lightReminderStays
                      : l10n.sleepTimerMinutes(minutes)),
                  selected: _offAfter == minutes,
                  onSelected: (_) => setState(() => _offAfter = minutes),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The night switch-off: which rooms, at what time, how slowly.
class NightOffEditor extends StatefulWidget {
  const NightOffEditor({this.current, super.key});

  /// The one set before, replaced on saving.
  final HueNightOff? current;

  @override
  State<NightOffEditor> createState() => _NightOffEditorState();
}

class _NightOffEditorState extends State<NightOffEditor> {
  late final _rooms = <String>{...?widget.current?.groupIds};
  late TimeOfDay _time = TimeOfDay(
    hour: widget.current?.hour ?? 1,
    minute: widget.current?.minute ?? 0,
  );
  late int _fade =
      HueNightOffDraft.fadeChoices.contains(widget.current?.fadeMinutes)
          ? widget.current!.fadeMinutes
          : 5;
  bool _saving = false;

  Future<void> _save() async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    if (client == null || _rooms.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await client.setNightOff(
        HueNightOffDraft(
          groupIds: _rooms.toList(),
          hour: _time.hour,
          minute: _time.minute,
          fadeMinutes: _fade,
        ),
        replacing: widget.current,
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nightOff),
        actions: [
          TextButton(
            onPressed: _saving || _rooms.isEmpty ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.nightOffDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.nightOffRooms, style: theme.textTheme.titleSmall),
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
                    if (on && _rooms.length < HueNightOffDraft.maxRooms) {
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
            leading: const Icon(Icons.nights_stay_outlined),
            title: Text(l10n.nightOffAt),
            trailing: Text(
                localizations.formatTimeOfDay(_time,
                    alwaysUse24HourFormat: h24),
                style: theme.textTheme.titleMedium),
            onTap: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) {
                setState(() => _time = picked);
              }
            },
          ),
          Text(l10n.nightOffFade, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final minutes in HueNightOffDraft.fadeChoices)
                ChoiceChip(
                  label: Text(l10n.sleepTimerMinutes(minutes)),
                  selected: _fade == minutes,
                  onSelected: (_) => setState(() => _fade = minutes),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
