import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'colour_mixing.dart';
import 'colour_words.dart';

enum _Mode { mix, quiz }

/// Mixing paints with light: pick two paints and the lamps show them,
/// then the colour they make; or guess what two paints make.
class ColourMixingScreen extends StatefulWidget {
  const ColourMixingScreen({this.playing, this.seed, super.key});

  /// The mix already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  /// Fixes the quiz (tests).
  final int? seed;

  @override
  State<ColourMixingScreen> createState() => _ColourMixingScreenState();
}

class _ColourMixingScreenState extends State<ColourMixingScreen> {
  late final _quiz =
      MixQuiz(widget.seed == null ? null : math.Random(widget.seed));
  var _mode = _Mode.mix;

  /// The paints picked: none, one, or the two mixed.
  late var _picked = switch (widget.playing) {
    final effect? => switch (ColourMix.of(effect)) {
        (final a, final b) => [a, b],
        null => <LearnColour>[],
      },
    null => <LearnColour>[],
  };
  bool? _right;
  var _generation = 0;

  String get _own => Localizations.localeOf(context).languageCode;

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _mix(LearnColour a, LearnColour b) async {
    final playback = AppScope.of(context).playback;
    await playback
        .switchEffect(ColourMix.effect(context.l10n.colourMixing, a, b));
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
    final language = _own;
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, speechLanguage(language));
    }());
  }

  Future<void> _pick(LearnColour paint) async {
    final picked = _picked.length == 1 ? [_picked.first, paint] : [paint];
    unawaited(HapticFeedback.selectionClick());
    setState(() => _picked = picked);
    if (picked case [final a, final b]) {
      // The lamps take a moment to stir: say the colour as it appears.
      final generation = ++_generation;
      await _mix(a, b);
      await Future<void>.delayed(const Duration(seconds: 4));
      if (mounted && generation == _generation && _picked.length == 2) {
        _say(mixOf(a, b)!.word(_own));
      }
    }
  }

  void _ask() {
    _generation++;
    setState(() {
      _quiz.next();
      _right = null;
    });
  }

  Future<void> _answer(LearnColour colour) async {
    if (_right == true) {
      return;
    }
    if (!_quiz.answer(colour)) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _right = false);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final generation = ++_generation;
    setState(() => _right = true);
    final (a, b) = _quiz.paints;
    _say(colour.word(_own));
    await _mix(a, b);
    await Future<void>.delayed(const Duration(seconds: 6));
    if (mounted && generation == _generation && _mode == _Mode.quiz) {
      _ask();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.colourMixing)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.colourMixingRules, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(
                value: _Mode.mix,
                icon: const Icon(Icons.palette_outlined),
                label: Text(l10n.colourMixingMix),
              ),
              ButtonSegment(
                value: _Mode.quiz,
                icon: const Icon(Icons.quiz_outlined),
                label: Text(l10n.colourWordsQuiz),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selected) {
              setState(() => _mode = selected.first);
              if (_mode == _Mode.quiz) {
                _ask();
              } else {
                _generation++;
              }
            },
          ),
          const SizedBox(height: 24),
          if (_mode == _Mode.mix)
            ..._mixing(context)
          else
            ..._quizzing(context),
        ],
      ),
    );
  }

  List<Widget> _mixing(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = _picked.length == 1 ? _picked.first : null;
    final mix = _picked.length == 2 ? mixOf(_picked[0], _picked[1]) : null;
    return [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final paint in mixingPaints)
            _Pot(
              colour: paint,
              label: paint.word(_own),
              size: 72,
              selected: _picked.contains(paint),
              // Only paints that make a colour with the first one.
              onTap: first == null || mixOf(first, paint) != null
                  ? () => _pick(paint)
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (mix == null)
        Text(
          first == null ? l10n.colourMixingPick : l10n.colourMixingPickAnother,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        )
      else
        _Result(
          sum: '${_picked[0].word(_own)} + ${_picked[1].word(_own)} = '
              '${mix.word(_own)}',
          colour: mix,
        ),
    ];
  }

  List<Widget> _quizzing(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_quiz.choices.isEmpty) {
      return const [];
    }
    final (a, b) = _quiz.paints;
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          switch (_right) {
            true => l10n.colourWordsRight,
            false => l10n.colourWordsTryAgain,
            null => l10n.colourMixingWhich(a.word(_own), b.word(_own)),
          },
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pot(colour: a, label: a.word(_own), size: 56, selected: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('+', style: theme.textTheme.headlineMedium),
          ),
          _Pot(colour: b, label: b.word(_own), size: 56, selected: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('= ?', style: theme.textTheme.headlineMedium),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final colour in _quiz.choices)
            _Pot(
              colour: colour,
              label: colour.word(_own),
              size: 104,
              selected: _right == true && colour == _quiz.target,
              onTap: () => _answer(colour),
            ),
        ],
      ),
    ];
  }
}

/// The colour two paints make, as a big card.
class _Result extends StatelessWidget {
  const _Result({required this.sum, required this.colour});

  final String sum;
  final LearnColour colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = LightColor.fromHex(colour.hex).toColor();
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Semantics(
          liveRegion: true,
          child: Text(
            sum,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A paint pot to tap, its colour's name under it.
class _Pot extends StatelessWidget {
  const _Pot({
    required this.colour,
    required this.label,
    required this.size,
    required this.selected,
    this.onTap,
  });

  final LearnColour colour;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = LightColor.fromHex(colour.hex).toColor();
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.35,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: color,
                  shape: CircleBorder(
                    side: selected
                        ? BorderSide(
                            color: theme.colorScheme.onSurface, width: 4)
                        : BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SizedBox.square(dimension: size),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
