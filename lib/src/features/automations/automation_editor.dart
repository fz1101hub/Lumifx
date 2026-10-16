import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_automations.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'automations_screen.dart';

/// A new wake-up or bedtime routine: when, which days, which rooms, how
/// long the fade lasts.
class AutomationEditor extends StatefulWidget {
  const AutomationEditor({super.key});

  static const fades = [5, 10, 20, 30, 60];

  @override
  State<AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<AutomationEditor> {
  HueAutomationKind _kind = HueAutomationKind.wakeUp;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  Set<int> _days = {0, 1, 2, 3, 4};
  final Set<String> _groups = {};
  int _fade = 20;
  bool _sunrise = true;
  bool _saving = false;
  final _name = TextEditingController();
  bool _nameEdited = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setKind(HueAutomationKind kind) {
    setState(() {
      _kind = kind;
      _time = kind == HueAutomationKind.wakeUp
          ? const TimeOfDay(hour: 7, minute: 0)
          : const TimeOfDay(hour: 22, minute: 30);
      _days = kind == HueAutomationKind.wakeUp
          ? {0, 1, 2, 3, 4}
          : {0, 1, 2, 3, 4, 5, 6};
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) {
      setState(() => _time = time);
    }
  }

  Future<void> _save(List<HueGroup> groups) async {
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    final l10n = context.l10n;
    if (client == null) {
      return;
    }
    setState(() => _saving = true);
    final name = _name.text.trim().isEmpty
        ? routineKindName(l10n, _kind)
        : _name.text.trim();
    try {
      await client.createAutomation(HueAutomationDraft(
        kind: _kind,
        name: name,
        hour: _time.hour,
        minute: _time.minute,
        days: _days.toList()..sort(),
        groups: [
          for (final g in groups)
            if (_groups.contains(g.id)) g,
        ],
        fade: Duration(minutes: _fade),
        sunrise: _sunrise,
      ));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error))),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final groups = [
      ...?AppScope.of(context).bridge.home?.groups,
    ].where((g) => g.lightIds.isNotEmpty).toList();
    if (!_nameEdited) {
      _name.text = routineKindName(l10n, _kind);
    }
    final canSave = !_saving && _groups.isNotEmpty;
    final wake = _kind == HueAutomationKind.wakeUp;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newRoutine),
        actions: [
          TextButton(
            onPressed: canSave ? () => _save(groups) : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final kind in HueAutomationKind.values)
                ChoiceChip(
                  avatar: Icon(kind == HueAutomationKind.wakeUp
                      ? Icons.wb_twilight
                      : Icons.bedtime_outlined),
                  label: Text(routineKindName(l10n, kind)),
                  selected: _kind == kind,
                  onSelected: (_) => _setKind(kind),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wake
                ? l10n.routineWakeUpDescription
                : l10n.routineGoToSleepDescription,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: HueBridgeClient.maxSceneNameLength,
            onChanged: (_) => _nameEdited = true,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title:
                Text(wake ? l10n.routineLightsOnAt : l10n.routineLightsOffAt),
            trailing: Text(
              _time.format(context),
              style: theme.textTheme.titleLarge,
            ),
            onTap: _pickTime,
          ),
          Text(l10n.routineDays, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(weekdayName(context, d)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    _days = {..._days};
                    on ? _days.add(d) : _days.remove(d);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(describeDays(context, _days.toList()..sort()),
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          Text(l10n.routineRooms, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (groups.isEmpty) Text(l10n.noBridgeConnected),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final group in groups)
                FilterChip(
                  label: Text(group.name),
                  selected: _groups.contains(group.id),
                  onSelected: (on) => setState(() {
                    on ? _groups.add(group.id) : _groups.remove(group.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(wake ? l10n.routineFadeIn : l10n.routineFadeOut,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final minutes in AutomationEditor.fades)
                ChoiceChip(
                  label: Text(l10n.sleepTimerMinutes(minutes)),
                  selected: _fade == minutes,
                  onSelected: (_) => setState(() => _fade = minutes),
                ),
            ],
          ),
          if (wake) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.routineSunrise),
              subtitle: Text(l10n.routineSunriseDescription),
              value: _sunrise,
              onChanged: (value) => setState(() => _sunrise = value),
            ),
          ],
        ],
      ),
    );
  }
}
