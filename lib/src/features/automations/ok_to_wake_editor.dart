import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_schedules.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'automations_screen.dart';

/// A new ok-to-wake light: which room, when the night glow starts, when
/// it turns green, on which mornings, and whether it switches off later.
class OkToWakeEditor extends StatefulWidget {
  const OkToWakeEditor({super.key});

  static const offChoices = [30, 60, 120];

  @override
  State<OkToWakeEditor> createState() => _OkToWakeEditorState();
}

class _OkToWakeEditorState extends State<OkToWakeEditor> {
  late final _name = TextEditingController(text: '');
  TimeOfDay _night = const TimeOfDay(hour: 19, minute: 30);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _mornings = {0, 1, 2, 3, 4, 5, 6};
  String? _groupId;
  int? _offMinutes = 60;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text = context.l10n.okToWake;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(TimeOfDay initial, ValueChanged<TimeOfDay> set) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => set(picked));
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final client = AppScope.of(context).bridge.client;
    final groupId = _groupId;
    if (client == null || groupId == null) {
      return;
    }
    if (_mornings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.okToWakeNoMornings)),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await client.createOkToWake(HueOkToWakeDraft(
        name: _name.text.trim().isEmpty ? l10n.okToWake : _name.text.trim(),
        groupId: groupId,
        nightHour: _night.hour,
        nightMinute: _night.minute,
        wakeHour: _wake.hour,
        wakeMinute: _wake.minute,
        mornings: _mornings.toList()..sort(),
        offAfter: _offMinutes == null ? null : Duration(minutes: _offMinutes!),
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
    String time(TimeOfDay t) =>
        localizations.formatTimeOfDay(t, alwaysUse24HourFormat: h24);
    final groups = [
      for (final group in AppScope.of(context).bridge.home?.groups ?? const [])
        if (group.idV1 != null && group.lightIds.isNotEmpty) group,
    ];
    final groupId = _groupId ?? groups.firstOrNull?.id;
    if (_groupId == null && groupId != null) {
      _groupId = groupId;
    }
    final selected = groups.where((g) => g.id == groupId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newOkToWake),
        actions: [
          TextButton(
            onPressed: _saving || selected == null ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.okToWakeDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: HueBridgeClient.maxSceneNameLength,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: selected?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.okToWakeRoom,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final group in groups)
                DropdownMenuItem(value: group.id, child: Text(group.name)),
            ],
            onChanged: (id) => setState(() => _groupId = id),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l10n.okToWakeNightAt),
            trailing: Text(time(_night), style: theme.textTheme.titleMedium),
            onTap: () => _pick(_night, (t) => _night = t),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l10n.okToWakeGreenAt),
            trailing: Text(time(_wake), style: theme.textTheme.titleMedium),
            onTap: () => _pick(_wake, (t) => _wake = t),
          ),
          const SizedBox(height: 8),
          Text(l10n.okToWakeMornings, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(weekdayName(context, d)),
                  selected: _mornings.contains(d),
                  onSelected: (on) => setState(
                    () => on ? _mornings.add(d) : _mornings.remove(d),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.okToWakeOffAfter, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(l10n.okToWakeStaysOn),
                selected: _offMinutes == null,
                onSelected: (_) => setState(() => _offMinutes = null),
              ),
              for (final minutes in OkToWakeEditor.offChoices)
                ChoiceChip(
                  label: Text(l10n.sleepTimerMinutes(minutes)),
                  selected: _offMinutes == minutes,
                  onSelected: (_) => setState(() => _offMinutes = minutes),
                ),
            ],
          ),
          if (groups.isEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.noBridgeConnected),
          ],
        ],
      ),
    );
  }
}
