import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'countdown.dart';

/// How many sleeps to the big days: a list of countdowns, each one a tap
/// away from the lights (a golden spark per sleep).
class CountdownsScreen extends StatelessWidget {
  const CountdownsScreen({super.key});

  Future<void> _show(BuildContext context, Countdown countdown) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final sleeps = countdown.sleepsFrom(scope.clock());
    final playback = scope.playback;
    await playback.switchEffect(
        countdown.effect(sleeps, countdown.sleepsText(sleeps, l10n)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _add(BuildContext context) async {
    final scope = AppScope.of(context);
    final countdown = await showDialog<Countdown>(
      context: context,
      builder: (_) => _CountdownDialog(today: scope.clock()),
    );
    if (countdown != null) {
      await scope.preferences.saveCountdown(countdown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final today = scope.clock();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.countdowns)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.countdownNew),
      ),
      body: ListenableBuilder(
        listenable: scope.preferences,
        builder: (context, _) {
          final countdowns = scope.preferences.countdowns;
          return ListView(
            padding: context.pageInsets(bottom: 96),
            children: [
              Text(l10n.countdownsDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (countdowns.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.countdownEmpty, textAlign: TextAlign.center),
                ),
              for (final countdown in countdowns)
                Builder(builder: (context) {
                  final sleeps = countdown.sleepsFrom(today);
                  final date =
                      DateFormat.yMMMMd(l10n.localeName).format(countdown.date);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child:
                            Text(sleeps < 0 ? '✓' : '${sleeps.clamp(0, 999)}'),
                      ),
                      title: Text(sleeps < 0
                          ? countdown.name
                          : countdown.sleepsText(sleeps, l10n)),
                      subtitle: Text(
                          sleeps < 0 ? '$date · ${l10n.countdownPast}' : date),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sleeps >= 0)
                            IconButton(
                              tooltip: l10n.countdownShow,
                              icon: const Icon(Icons.lightbulb_outline),
                              onPressed: () => _show(context, countdown),
                            ),
                          IconButton(
                            tooltip: l10n.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                scope.preferences.deleteCountdown(countdown.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.today});

  final DateTime today;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  final _name = TextEditingController();
  late DateTime _date =
      DateTime(widget.today.year, widget.today.month, widget.today.day + 7);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = widget.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 3, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMMd(l10n.localeName).format(_date);
    return AlertDialog(
      title: Text(l10n.countdownNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: Countdown.maxName,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.countdownName,
              hintText: l10n.countdownNameHint,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(date),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(Countdown(
                    id: Countdown.newId(),
                    name: _name.text,
                    date: _date,
                  )),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
