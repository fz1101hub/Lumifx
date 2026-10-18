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
import 'colour_words.dart';

enum _Mode { learn, quiz }

/// The colours in another language: the room turns a colour and the
/// phone says its name; then a quiz, hear the word and tap the colour.
class ColourWordsScreen extends StatefulWidget {
  const ColourWordsScreen({this.playing, this.seed, super.key});

  /// The colour already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  /// Fixes the quiz (tests).
  final int? seed;

  @override
  State<ColourWordsScreen> createState() => _ColourWordsScreenState();
}

class _ColourWordsScreenState extends State<ColourWordsScreen> {
  late final _quiz =
      ColourQuiz(widget.seed == null ? null : math.Random(widget.seed));
  late LearnColour _colour = switch (widget.playing) {
        final effect? => LearnColour.of(effect),
        null => null,
      } ??
      LearnColour.red;
  String? _language;
  var _mode = _Mode.learn;
  bool? _right;
  var _generation = 0;

  String get _own => Localizations.localeOf(context).languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The language chosen last time; else English to start with, or
    // Spanish for whoever speaks it already.
    final saved = AppScope.of(context).preferences.learnLanguage;
    _language ??=
        saved != null && saved != _own && learnLanguages.containsKey(saved)
            ? saved
            : (_own == 'en' ? 'es' : 'en');
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _light(LearnColour colour) async {
    final playback = AppScope.of(context).playback;
    await playback.switchEffect(colour.effect(context.l10n.colourWords));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  void _say(LearnColour colour) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language = _language!;
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker
          .speak(colour.word(language), speechLanguage(language));
    }());
  }

  Future<void> _show(LearnColour colour) async {
    setState(() => _colour = colour);
    _say(colour);
    await _light(colour);
  }

  void _ask() {
    _generation++;
    setState(() {
      _quiz.next();
      _right = null;
    });
    _say(_quiz.target);
  }

  Future<void> _answer(LearnColour colour) async {
    if (_right == true) {
      return;
    }
    if (!_quiz.answer(colour)) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _right = false);
      _say(_quiz.target);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final generation = ++_generation;
    setState(() {
      _right = true;
      _colour = colour;
    });
    await _light(colour);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted && generation == _generation && _mode == _Mode.quiz) {
      _ask();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.colourWords)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) => ListView(
          padding: context.pageInsets(),
          children: [
            Text(l10n.colourWordsRules, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(l10n.colourWordsLanguage, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: code, value: name)
                    in learnLanguages.entries)
                  if (code != _own)
                    ChoiceChip(
                      label: Text(name),
                      selected: _language == code,
                      onSelected: (_) {
                        setState(() => _language = code);
                        unawaited(AppScope.of(context)
                            .preferences
                            .setLearnLanguage(code));
                        _say(_mode == _Mode.quiz && _quiz.choices.isNotEmpty
                            ? _quiz.target
                            : _colour);
                      },
                    ),
              ],
            ),
            if (!preferences.soundOn) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: SwitchListTile(
                  secondary: const Icon(Icons.volume_off_outlined),
                  title: Text(l10n.colourWordsSoundOff),
                  value: preferences.soundOn,
                  onChanged: preferences.setSoundOn,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<_Mode>(
              segments: [
                ButtonSegment(
                  value: _Mode.learn,
                  icon: const Icon(Icons.school_outlined),
                  label: Text(l10n.colourWordsLearn),
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
            const SizedBox(height: 16),
            if (_mode == _Mode.learn)
              ..._learn(context)
            else
              ..._quizzing(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _learn(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = LightColor.fromHex(_colour.hex).toColor();
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return [
      Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  _colour.word(_language!),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _colour.word(_own),
                style: theme.textTheme.titleLarge?.copyWith(color: onColor),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _say(_colour),
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l10n.colourWordsSayAgain),
          ),
          FilledButton.icon(
            onPressed: () => _show(LearnColour
                .values[(_colour.index + 1) % LearnColour.values.length]),
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.colourWordsNext),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final colour in LearnColour.values)
            _Swatch(
              colour: colour,
              label: colour.word(_own),
              size: 48,
              selected: colour == _colour,
              onTap: () => _show(colour),
            ),
        ],
      ),
    ];
  }

  List<Widget> _quizzing(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_quiz.choices.isEmpty) {
      return const [];
    }
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          switch (_right) {
            true => l10n.colourWordsRight,
            false => l10n.colourWordsTryAgain,
            null => l10n.colourWordsWhich,
          },
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            textStyle: theme.textTheme.headlineMedium,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () => _say(_quiz.target),
          icon: const Icon(Icons.volume_up_outlined, size: 32),
          label: Text(_quiz.target.word(_language!)),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final colour in _quiz.choices)
            _Swatch(
              colour: colour,
              label: colour.word(_own),
              size: 120,
              selected: _right == true && colour == _quiz.target,
              onTap: () => _answer(colour),
            ),
        ],
      ),
    ];
  }
}

/// A colour to tap, named for screen readers in the child's language.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final LearnColour colour;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = LightColor.fromHex(colour.hex).toColor();
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color,
        shape: CircleBorder(
          side: selected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.onSurface, width: 4)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: size),
        ),
      ),
    );
  }
}
