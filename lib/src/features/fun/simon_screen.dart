import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'simon.dart';

enum _Stage { intro, watch, yourTurn, over }

/// The memory game: watch the lights, then tap the colours in the same
/// order; one more each round.
class SimonScreen extends StatefulWidget {
  const SimonScreen({this.seed, super.key});

  /// Fixes the colours drawn (tests).
  final int? seed;

  static String nameOf(AppLocalizations l10n, SimonColor color) =>
      switch (color) {
        SimonColor.red => l10n.simonRed,
        SimonColor.green => l10n.simonGreen,
        SimonColor.blue => l10n.simonBlue,
        SimonColor.yellow => l10n.simonYellow,
      };

  @override
  State<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends State<SimonScreen> {
  late PlaybackController _playback;
  SimonGame? _game;
  var _stage = _Stage.intro;
  SimonColor? _lit;
  var _newBest = false;

  /// Bumped to abandon a sequence being shown.
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
    final game = SimonGame(seed == null ? null : math.Random(seed));
    setState(() {
      _game = game;
      _newBest = false;
    });
    final background = SimonGame.background(l10n.gameSimon);
    if (_playback.effect.id != background.id ||
        _playback.status == PlaybackStatus.idle) {
      await _playback.switchEffect(background);
    }
    if (_playback.status == PlaybackStatus.idle) {
      await _playback.start();
    } else if (_playback.status == PlaybackStatus.paused) {
      await _playback.resume();
    }
    await _nextRound();
  }

  Future<void> _nextRound() async {
    final game = _game;
    if (game == null || !mounted) {
      return;
    }
    game.nextRound();
    final generation = ++_generation;
    setState(() => _stage = _Stage.watch);
    // A breath before the lights start.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (final color in game.sequence) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _lit = color);
      _playback.flash(LightColor.fromHex(color.hex), length: game.showLength);
      await Future<void>.delayed(game.showLength);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _lit = null);
      await Future<void>.delayed(game.gapLength);
    }
    if (mounted && generation == _generation) {
      setState(() => _stage = _Stage.yourTurn);
    }
  }

  Future<void> _press(SimonColor color) async {
    final game = _game;
    if (game == null || _stage != _Stage.yourTurn) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    _playback.flash(LightColor.fromHex(color.hex),
        length: const Duration(milliseconds: 400));
    final generation = ++_generation;
    setState(() => _lit = color);
    final result = game.press(color);
    if (result == SimonPress.wrong) {
      final preferences = AppScope.of(context).preferences;
      setState(() {
        _lit = null;
        _stage = _Stage.over;
        _newBest = preferences.recordSimonScore(game.score);
      });
      unawaited(HapticFeedback.heavyImpact());
      _playback.flash(const LightColor(1, 1, 1),
          length: const Duration(milliseconds: 1200));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _lit = null);
    if (result == SimonPress.roundDone) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted && generation == _generation) {
        await _nextRound();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final game = _game;
    final best = AppScope.of(context).preferences.simonBest;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameSimon)),
      body: _stage == _Stage.intro || game == null
          ? ListView(
              padding: context.pageInsets(),
              children: [
                Icon(Icons.psychology_outlined,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.gameSimonRules, style: theme.textTheme.bodyLarge),
                if (best > 0) ...[
                  const SizedBox(height: 12),
                  Text(l10n.simonBest(best),
                      style: theme.textTheme.titleMedium),
                ],
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        switch (_stage) {
                          _Stage.watch => l10n.simonWatch,
                          _Stage.yourTurn => l10n.simonYourTurn,
                          _ => l10n.simonOops(game.score),
                        },
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stage == _Stage.over
                          ? (_newBest
                              ? l10n.simonNewBest
                              : l10n.simonBest(best))
                          : l10n.simonRound(game.round),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final color in SimonColor.values)
                            _ColorPad(
                              color: color,
                              label: SimonScreen.nameOf(l10n, color),
                              lit: _lit == color,
                              enabled: _stage == _Stage.yourTurn,
                              onTap: () => _press(color),
                            ),
                        ],
                      ),
                    ),
                    if (_stage == _Stage.over)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.replay),
                            label: Text(l10n.gameAgain),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.close),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// One big colour to tap; bright while lit.
class _ColorPad extends StatelessWidget {
  const _ColorPad({
    required this.color,
    required this.label,
    required this.lit,
    required this.enabled,
    required this.onTap,
  });

  final SimonColor color;
  final String label;
  final bool lit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = LightColor.fromHex(color.hex).toColor();
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: lit ? base : Color.lerp(base, Colors.black, 0.55),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: lit
                  ? [BoxShadow(color: base, blurRadius: 24, spreadRadius: 2)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
