import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/color/light_color.dart';
import '../../core/screen_wake.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'sound_alerts.dart';

/// Light alerts for sounds: while open, the microphone listens for a smoke
/// alarm, the doorbell or a baby crying, and the lamps flash in that
/// sound's colour. The screen stays on meanwhile.
class SoundAlertsScreen extends StatefulWidget {
  const SoundAlertsScreen({
    this.screenWake = const WakelockScreenWake(holder: 'sound_alerts'),
    super.key,
  });

  final ScreenWake screenWake;

  static String nameOf(AppLocalizations l10n, SoundAlert alert) =>
      switch (alert) {
        SoundAlert.smokeAlarm => l10n.alertSmokeAlarm,
        SoundAlert.doorbell => l10n.alertDoorbell,
        SoundAlert.babyCrying => l10n.alertBabyCrying,
      };

  static IconData iconOf(SoundAlert alert) => switch (alert) {
        SoundAlert.smokeAlarm => Icons.local_fire_department_outlined,
        SoundAlert.doorbell => Icons.doorbell_outlined,
        SoundAlert.babyCrying => Icons.child_friendly_outlined,
      };

  @override
  State<SoundAlertsScreen> createState() => _SoundAlertsScreenState();
}

class _SoundAlertsScreenState extends State<SoundAlertsScreen>
    with WidgetsBindingObserver {
  late AudioInput _microphone;
  StreamSubscription<Uint8List>? _listening;
  SoundWatch? _watch;
  final _watching = SoundAlert.values.toSet();
  (SoundAlert, DateTime)? _heard;
  var _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _microphone = AppScope.of(context).audioInput;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _listening != null) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final listening = _listening;
    _listening = null;
    if (listening != null) {
      unawaited(listening.cancel());
      unawaited(_microphone.stop());
      unawaited(widget.screenWake.keepOn(false));
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      if (!await _microphone.requestPermission()) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.soundAlertsMicDenied)));
        return;
      }
      final watch = SoundWatch(
          sampleRate: _microphone.sampleRate, watching: {..._watching});
      final audio = await _microphone.start();
      if (!mounted) {
        await _microphone.stop();
        return;
      }
      unawaited(widget.screenWake.keepOn(true));
      setState(() {
        _watch = watch;
        _listening = audio.listen((pcm) {
          for (final alert in watch.add(pcm)) {
            unawaited(_tell(alert));
          }
        }, onError: (Object error) {
          debugPrint('Sound alerts: $error');
          unawaited(_stop());
        }, onDone: () => unawaited(_stop()));
      });
    } on Object catch (error) {
      debugPrint('Sound alerts: $error');
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.soundAlertsMicDenied)));
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _stop() async {
    final listening = _listening;
    _listening = null;
    _watch = null;
    if (listening != null) {
      unawaited(listening.cancel());
      await _microphone.stop();
      unawaited(widget.screenWake.keepOn(false));
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// The lamps tell about [alert].
  Future<void> _tell(SoundAlert alert, {bool test = false}) async {
    if (!mounted) {
      return;
    }
    final scope = AppScope.of(context);
    final playback = scope.playback;
    unawaited(HapticFeedback.heavyImpact());
    if (!test) {
      setState(() => _heard = (alert, scope.clock()));
    }
    playback.setSleepTimer(null);
    await playback.switchEffect(
        alert.effect(SoundAlertsScreen.nameOf(context.l10n, alert)));
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
    final playback = AppScope.of(context).playback;
    final heard = _heard;
    final listening = _listening != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.soundAlerts)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.soundAlertsDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final alert in SoundAlert.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: LightColor.fromHex(alert.color).toColor(),
                child:
                    Icon(SoundAlertsScreen.iconOf(alert), color: Colors.white),
              ),
              title: Text(SoundAlertsScreen.nameOf(l10n, alert)),
              value: _watching.contains(alert),
              onChanged: (on) => setState(() {
                if (on == true) {
                  _watching.add(alert);
                } else {
                  _watching.remove(alert);
                }
                _watch?.watching = {..._watching};
              }),
            ),
          const SizedBox(height: 16),
          if (heard != null)
            ListenableBuilder(
              listenable: playback,
              builder: (context, _) {
                final (alert, at) = heard;
                final showing = SoundAlert.of(playback.effect) == alert &&
                    playback.status != PlaybackStatus.idle;
                return Card(
                  color: LightColor.fromHex(alert.color)
                      .toColor()
                      .withValues(alpha: 0.25),
                  child: ListTile(
                    leading: Icon(SoundAlertsScreen.iconOf(alert), size: 36),
                    title: Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.soundAlertsHeard(
                            SoundAlertsScreen.nameOf(l10n, alert),
                            MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay.fromDateTime(at),
                                alwaysUse24HourFormat:
                                    MediaQuery.alwaysUse24HourFormatOf(
                                        context))),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    trailing: showing
                        ? TextButton(
                            onPressed: playback.stop,
                            child: Text(l10n.soundAlertsStopLights),
                          )
                        : null,
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          if (listening) ...[
            Row(
              children: [
                const Icon(Icons.hearing),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.soundAlertsListening,
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: Text(l10n.stop),
              ),
            ),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _starting || _watching.isEmpty ? null : _start,
              icon: const Icon(Icons.mic_none),
              label: Text(l10n.soundAlertsStart),
            ),
          const SizedBox(height: 24),
          Text(l10n.soundAlertsTry, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final alert in SoundAlert.values)
                ActionChip(
                  avatar: Icon(SoundAlertsScreen.iconOf(alert)),
                  label: Text(SoundAlertsScreen.nameOf(l10n, alert)),
                  onPressed: () => _tell(alert, test: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
