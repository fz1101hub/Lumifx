import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'moon.dart';

/// Tonight's moon: its phase drawn and named, how much is lit, when the
/// next full moon is, and the lamps showing it with a sentence before bed.
class MoonScreen extends StatelessWidget {
  const MoonScreen({super.key});

  static String phaseName(AppLocalizations l10n, MoonPhase phase) =>
      switch (phase) {
        MoonPhase.newMoon => l10n.moonNew,
        MoonPhase.waxingCrescent => l10n.moonWaxingCrescent,
        MoonPhase.firstQuarter => l10n.moonFirstQuarter,
        MoonPhase.waxingGibbous => l10n.moonWaxingGibbous,
        MoonPhase.full => l10n.moonFull,
        MoonPhase.waningGibbous => l10n.moonWaningGibbous,
        MoonPhase.lastQuarter => l10n.moonLastQuarter,
        MoonPhase.waningCrescent => l10n.moonWaningCrescent,
      };

  Future<void> _show(BuildContext context, DateTime now) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final playback = scope.playback;
    final phase = phaseName(l10n, Moon.phaseOf(now));
    if (scope.preferences.soundOn) {
      final language =
          speechLanguage(Localizations.localeOf(context).languageCode);
      unawaited(() async {
        await scope.speaker.stop();
        await scope.speaker
            .speak(l10n.moonTonight(phase), language, style: SpeechStyle.story);
      }());
    }
    playback.setSleepTimer(null);
    await playback.switchEffect(Moon.effect(l10n.moon, now));
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
    // Tonight: at 9 in the evening of today.
    final today = AppScope.of(context).clock();
    final now = DateTime(today.year, today.month, today.day, 21);
    final lit = Moon.litOf(now);
    final phase = Moon.phaseOf(now);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moon)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.moonDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Center(
            child: Semantics(
              label: phaseName(l10n, phase),
              excludeSemantics: true,
              child: CustomPaint(
                size: const Size.square(180),
                painter: MoonPainter(
                  lit: lit,
                  waxing: Moon.isWaxing(now),
                  light: LightColor.fromHex(Moon.moonlight).toColor(),
                  dark: LightColor.fromHex(Moon.night).toColor(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            phaseName(l10n, phase),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.moonLit((lit * 100).round())} · '
            '${l10n.moonFullIn(Moon.daysToFull(now))}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => _show(context, now),
            icon: const Icon(Icons.nightlight_round),
            label: Text(l10n.moonShow),
          ),
        ],
      ),
    );
  }
}

/// The moon with [lit] of it lit (0..1), on the right while [waxing].
class MoonPainter extends CustomPainter {
  const MoonPainter({
    required this.lit,
    required this.waxing,
    required this.light,
    required this.dark,
  });

  final double lit;
  final bool waxing;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, r, Paint()..color = dark);
    // The lit half, then the terminator as half an ellipse: lit for a
    // gibbous moon, dark for a crescent.
    final side = waxing ? 1.0 : -1.0;
    final half = Path()
      ..addArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2,
          side * math.pi)
      ..close();
    canvas.drawPath(half, Paint()..color = light);
    final width = r * (1 - 2 * lit).abs();
    final ellipse =
        Rect.fromCenter(center: center, width: width * 2, height: r * 2);
    canvas.drawOval(ellipse, Paint()..color = lit > 0.5 ? light : dark);
  }

  @override
  bool shouldRepaint(MoonPainter old) => old.lit != lit || old.waxing != waxing;
}
