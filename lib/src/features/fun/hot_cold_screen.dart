import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'hot_cold.dart';

/// Hot and cold: a grown-up taps Warmer or Colder as the child looks for
/// something hidden, and the lights (and the phone's voice) tell them.
class HotColdScreen extends StatefulWidget {
  const HotColdScreen({super.key});

  @override
  State<HotColdScreen> createState() => _HotColdScreenState();
}

class _HotColdScreenState extends State<HotColdScreen> {
  int? _level;
  var _found = false;

  Future<void> _play(PlaybackController playback, LightingEffect effect) async {
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language = Localizations.localeOf(context).languageCode;
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, speechLanguage(language));
    }());
  }

  Future<void> _set(int level) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final next = level.clamp(0, HotCold.hottest);
    final word = HotCold.wordOf(l10n, next);
    final changed = _level == null || HotCold.wordOf(l10n, _level!) != word;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _level = next;
      _found = false;
    });
    if (changed) {
      _say(word);
    }
    await _play(playback, HotCold.effect(next, l10n.hotCold));
  }

  Future<void> _foundIt() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _found = true);
    _say(l10n.hotColdFound);
    await _play(playback, HotCold.found(l10n.hotCold));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final level = _level;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hotCold)),
      body: level == null
          ? ListView(
              padding: context.pageInsets(),
              children: [
                Icon(Icons.thermostat,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.hotColdRules, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: () => _set(HotCold.start),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.timerStart),
                ),
              ],
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _found ? l10n.hotColdFound : HotCold.wordOf(l10n, level),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Thermometer(level: level),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(88),
                            backgroundColor: HotCold.colorOf(0).toColor(),
                            foregroundColor: Colors.white,
                            textStyle: theme.textTheme.titleLarge,
                          ),
                          onPressed: level > 0 ? () => _set(level - 1) : null,
                          icon: const Icon(Icons.ac_unit, size: 32),
                          label: Text(l10n.hotColdColder),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(88),
                            backgroundColor:
                                HotCold.colorOf(HotCold.hottest).toColor(),
                            foregroundColor: Colors.white,
                            textStyle: theme.textTheme.titleLarge,
                          ),
                          onPressed: level < HotCold.hottest
                              ? () => _set(level + 1)
                              : null,
                          icon: const Icon(Icons.local_fire_department_outlined,
                              size: 32),
                          label: Text(l10n.hotColdWarmer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_found)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                      onPressed: () => _set(HotCold.start),
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.gameAgain),
                    )
                  else
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                      onPressed: _foundIt,
                      icon: const Icon(Icons.celebration_outlined),
                      label: Text(l10n.hotColdFound),
                    ),
                ],
              ),
            ),
    );
  }
}

/// How hot it is, from icy blue to red.
class _Thermometer extends StatelessWidget {
  const _Thermometer({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 32,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (level + 1) / (HotCold.hottest + 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      HotCold.colorOf(0).toColor(),
                      HotCold.colorOf(level).toColor(),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
