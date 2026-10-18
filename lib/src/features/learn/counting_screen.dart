import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'counting.dart';

enum _Stage { intro, watch, answer, right }

/// Count the lights: the lamps (and a lamp on screen) blink, the child
/// taps how many.
class CountingScreen extends StatefulWidget {
  const CountingScreen({this.seed, super.key});

  /// Fixes the numbers drawn (tests).
  final int? seed;

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  late PlaybackController _playback;
  CountingGame? _game;
  var _stage = _Stage.intro;
  String? _lit;
  var _missed = false;

  /// Bumped to abandon blinks being shown.
  var _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playback = AppScope.of(context).playback;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final seed = widget.seed;
    setState(
        () => _game = CountingGame(seed == null ? null : math.Random(seed)));
    final background = CountingGame.background(l10n.countLights);
    if (_playback.effect.id != background.id ||
        _playback.status == PlaybackStatus.idle) {
      await _playback.switchEffect(background);
    }
    if (_playback.status == PlaybackStatus.idle) {
      await _playback.start();
    } else if (_playback.status == PlaybackStatus.paused) {
      await _playback.resume();
    }
    await _blink(fresh: true);
  }

  /// Blinks the lamps: a new number, or the same again.
  Future<void> _blink({required bool fresh}) async {
    final game = _game;
    if (game == null || !mounted) {
      return;
    }
    if (fresh) {
      game.next();
      _missed = false;
    }
    final generation = ++_generation;
    setState(() => _stage = _Stage.watch);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    for (final color in game.colors) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _lit = color);
      _playback.flash(LightColor.fromHex(color), length: CountingGame.blink);
      await Future<void>.delayed(CountingGame.blink);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _lit = null);
      await Future<void>.delayed(CountingGame.gap);
    }
    if (mounted && generation == _generation) {
      setState(() => _stage = _Stage.answer);
    }
  }

  Future<void> _answer(int count) async {
    final game = _game;
    if (game == null || _stage != _Stage.answer) {
      return;
    }
    final scope = AppScope.of(context);
    final language = Localizations.localeOf(context).languageCode;
    if (!game.answer(count)) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _missed = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await _blink(fresh: false);
      }
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final generation = ++_generation;
    setState(() => _stage = _Stage.right);
    _playback.flash(const LightColor(1, 0.85, 0.4),
        length: const Duration(milliseconds: 1200));
    if (scope.preferences.soundOn) {
      unawaited(scope.speaker.speak('$count', speechLanguage(language)));
    }
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted && generation == _generation) {
      await _blink(fresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final game = _game;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.countLights)),
      body: _stage == _Stage.intro || game == null
          ? ListView(
              padding: context.pageInsets(),
              children: [
                Icon(Icons.filter_9_plus_outlined,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.countLightsRules, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: _start,
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
                      switch (_stage) {
                        _Stage.watch => l10n.countWatch,
                        _Stage.right => l10n.countRight(game.target),
                        _ => _missed ? l10n.countWrong : l10n.countHowMany,
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.countScore(game.score),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Center(child: _Lamp(color: _lit)),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var n = 1; n <= game.max; n++)
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: theme.textTheme.headlineMedium,
                            ),
                            onPressed: _stage == _Stage.answer
                                ? () => _answer(n)
                                : null,
                            child: Text('$n'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _stage == _Stage.answer
                          ? () => _blink(fresh: false)
                          : null,
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.countAgain),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The blinks on screen too, for counting along without lamps.
class _Lamp extends StatelessWidget {
  const _Lamp({required this.color});

  final String? color;

  @override
  Widget build(BuildContext context) {
    final lit = color == null ? null : LightColor.fromHex(color!).toColor();
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: lit == null
              ? null
              : [BoxShadow(color: lit, blurRadius: 32, spreadRadius: 4)],
        ),
      ),
    );
  }
}
