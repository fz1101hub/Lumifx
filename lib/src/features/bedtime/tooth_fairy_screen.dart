import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'tooth_fairy.dart';

/// The tooth fairy: plan her visit for tonight (a soft glow near dawn,
/// kept on the bridge), then in the morning read her message, which
/// gives the child a magic star.
class ToothFairyScreen extends StatefulWidget {
  const ToothFairyScreen({super.key});

  @override
  State<ToothFairyScreen> createState() => _ToothFairyScreenState();
}

class _ToothFairyScreenState extends State<ToothFairyScreen> {
  String? _child;
  String? _room;
  TimeOfDay _time = const TimeOfDay(hour: ToothFairy.defaultHour, minute: 0);
  String? _read;
  bool _busy = false;

  Future<void> _plan() async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final now = scope.clock();
    var at = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    setState(() => _busy = true);
    try {
      final client = scope.bridge.client;
      final room = _room;
      if (client != null && room != null) {
        await client.createFairyVisit(
            groupId: room, hour: _time.hour, minute: _time.minute);
      }
      await scope.preferences.setToothFairy((
        child: _child ?? scope.preferences.activeChildId,
        at: at,
      ));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error))),
      ));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel() async {
    final scope = AppScope.of(context);
    try {
      await scope.bridge.client?.cancelFairyVisits();
    } on Object {
      // Gone already, or the bridge is away: forget the visit anyway.
    }
    await scope.preferences.setToothFairy(null);
  }

  /// The morning after: her message, said aloud, and the star.
  Future<void> _readMessage(({String child, DateTime at}) visit) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final preferences = scope.preferences;
    final name = preferences.children
            .where((c) => c.id == visit.child)
            .firstOrNull
            ?.name ??
        l10n.toothFairyFriend;
    final message = l10n.toothFairyMessage(name);
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    setState(() => _read = message);
    preferences.earnStar(ToothFairy.starKey(visit.at), child: visit.child);
    await preferences.setToothFairy(null);
    if (!mounted) {
      return;
    }
    if (preferences.soundOn) {
      unawaited(() async {
        await scope.speaker.stop();
        await scope.speaker.speak(message, language, style: SpeechStyle.story);
      }());
    }
    await _magic();
  }

  Future<void> _magic() async {
    final playback = AppScope.of(context).playback;
    playback.setSleepTimer(null);
    await playback.switchEffect(ToothFairy.effect(context.l10n.toothFairy));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
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
      appBar: AppBar(title: Text(l10n.toothFairy)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final visit = preferences.toothFairy;
          final now = scope.clock();
          final groups = [
            for (final group in scope.bridge.home?.groups ?? const [])
              if (group.idV1 != null && group.lightIds.isNotEmpty) group,
          ];
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.toothFairyDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (_read case final message?)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(message,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                )
              else if (visit != null && !now.isBefore(visit.at)) ...[
                Text(l10n.toothFairyCame,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: () => _readMessage(visit),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(l10n.toothFairyRead),
                ),
              ] else if (visit != null) ...[
                Text(
                  l10n.toothFairyComing(localizations.formatTimeOfDay(
                      TimeOfDay.fromDateTime(visit.at),
                      alwaysUse24HourFormat: h24)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _cancel,
                    child: Text(l10n.toothFairyCancel),
                  ),
                ),
              ] else ...[
                if (preferences.children.isNotEmpty) ...[
                  Text(l10n.toothFairyFor, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final child in preferences.children)
                        ChoiceChip(
                          label: Text(child.name),
                          selected:
                              (_child ?? preferences.activeChildId) == child.id,
                          onSelected: (_) => setState(() => _child = child.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (groups.isNotEmpty) ...[
                  Text(l10n.toothFairyRoom, style: theme.textTheme.titleSmall),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wb_twilight),
                    title: Text(l10n.toothFairyTime),
                    trailing: Text(
                        localizations.formatTimeOfDay(_time,
                            alwaysUse24HourFormat: h24),
                        style: theme.textTheme.titleMedium),
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: _time);
                      if (picked != null) {
                        setState(() => _time = picked);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy ? null : _plan,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(l10n.toothFairyPlan),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _magic,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(l10n.toothFairyMagic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
