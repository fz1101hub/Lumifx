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
import '../learn/colour_words.dart';
import '../learn/farm_screen.dart';
import 'family_quiz.dart';

/// The family quiz: questions read aloud, teams buzz on the phone in their
/// colour (the room lights up in it), a grown-up says right or wrong.
class FamilyQuizScreen extends StatefulWidget {
  const FamilyQuizScreen({this.seed, super.key});

  /// Fixes the questions (tests).
  final int? seed;

  static String _capitalised(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  static String question(
          AppLocalizations l10n, String language, QuizQuestion q) =>
      switch (q) {
        SoundQuestion(:final animal) =>
          l10n.farmWhoSays(FarmScreen.soundOf(l10n, animal)),
        ColourQuestion() => l10n.quizWhatColour,
        SumQuestion(:final a, :final b, op: SumOp.plus) => l10n.quizPlus(a, b),
        SumQuestion(:final a, :final b, op: SumOp.minus) =>
          l10n.quizMinus(a, b),
        SumQuestion(:final a, :final b, op: SumOp.times) =>
          l10n.quizTimes(a, b),
        MixQuestion(:final a, :final b) =>
          l10n.quizMix(a.word(language), b.word(language)),
      };

  static String answer(
          AppLocalizations l10n, String language, QuizQuestion q) =>
      _capitalised(switch (q) {
        SoundQuestion(:final animal) => FarmScreen.nameOf(l10n, animal),
        ColourQuestion(:final colour) => colour.word(language),
        SumQuestion() => '${q.answer}',
        MixQuestion(:final mix) => mix.word(language),
      });

  @override
  State<FamilyQuizScreen> createState() => _FamilyQuizScreenState();
}

class _FamilyQuizScreenState extends State<FamilyQuizScreen> {
  late final _random =
      widget.seed == null ? math.Random() : math.Random(widget.seed);
  var _pack = QuizPack.kids;
  var _teams = 2;

  List<QuizQuestion>? _questions;
  var _index = 0;
  var _scores = <int>[];

  /// The team answering now.
  int? _buzzed;

  /// Teams that got this question wrong.
  final _out = <int>{};
  var _generation = 0;

  String get _language => Localizations.localeOf(context).languageCode;

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language = speechLanguage(_language);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language);
    }());
  }

  Future<void> _lights(QuizQuestion question) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    playback.setSleepTimer(null);
    await playback.switchEffect(switch (question) {
      ColourQuestion(:final colour) => colour.effect(l10n.familyQuiz),
      _ => FamilyQuiz.studio(l10n.familyQuiz),
    });
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  void _start() {
    setState(() {
      _questions = FamilyQuiz.make(_pack, _random);
      _scores = List.filled(_teams, 0);
    });
    _show(0);
  }

  void _show(int index) {
    final questions = _questions!;
    _generation++;
    setState(() {
      _index = index;
      _buzzed = null;
      _out.clear();
    });
    if (index >= questions.length) {
      unawaited(_finish());
      return;
    }
    final question = questions[index];
    // The colour shows first, then the question about it.
    unawaited(_lights(question));
    _say(FamilyQuizScreen.question(context.l10n, _language, question));
  }

  void _buzz(int team) {
    if (_buzzed != null || _out.contains(team)) {
      return;
    }
    final colour = FamilyQuiz.teams[team];
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _buzzed = team);
    AppScope.of(context).playback.flash(LightColor.fromHex(colour.hex),
        length: const Duration(milliseconds: 1200));
    _say(context.l10n.quizTeamTurn(colour.word(_language)));
  }

  Future<void> _judge(bool right) async {
    final team = _buzzed;
    if (team == null) {
      return;
    }
    final l10n = context.l10n;
    if (right) {
      setState(() => _scores[team]++);
      _say(l10n.colourWordsRight);
      final generation = ++_generation;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted && generation == _generation) {
        _show(_index + 1);
      }
      return;
    }
    _say(l10n.colourWordsTryAgain);
    setState(() {
      _out.add(team);
      _buzzed = null;
    });
  }

  Future<void> _finish() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final best = _scores.fold(0, math.max);
    final winners = [
      for (var t = 0; t < _scores.length; t++)
        if (_scores[t] == best) t,
    ];
    if (winners.length != 1) {
      _say(l10n.quizDraw);
      await playback.switchEffect(FamilyQuiz.studio(l10n.familyQuiz));
      return;
    }
    final team = FamilyQuiz.teams[winners.single];
    _say(l10n.quizWinner(team.word(_language)));
    await playback.switchEffect(FamilyQuiz.winner(l10n.familyQuiz, team));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyQuiz)),
      body: questions == null
          ? _setup(context)
          : _index >= questions.length
              ? _end(context)
              : _playing(context, questions[_index]),
    );
  }

  Widget _setup(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.familyQuizDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.quizPack, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final pack in QuizPack.values)
              ChoiceChip(
                label: Text(switch (pack) {
                  QuizPack.little => l10n.quizPackLittle,
                  QuizPack.kids => l10n.quizPackKids,
                  QuizPack.family => l10n.quizPackFamily,
                }),
                selected: _pack == pack,
                onSelected: (_) => setState(() => _pack = pack),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.quizTeams, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var n = FamilyQuiz.minTeams; n <= FamilyQuiz.maxTeams; n++)
              ChoiceChip(
                label: Text('$n'),
                selected: _teams == n,
                onSelected: (_) => setState(() => _teams = n),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.quiz_outlined),
          label: Text(l10n.quizStart),
        ),
      ],
    );
  }

  Widget _scoreRow(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var t = 0; t < _scores.length; t++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Chip(
              avatar: CircleAvatar(
                  backgroundColor:
                      LightColor.fromHex(FamilyQuiz.teams[t].hex).toColor()),
              label: Text('${_scores[t]}', style: theme.textTheme.titleMedium),
            ),
          ),
      ],
    );
  }

  Widget _playing(BuildContext context, QuizQuestion question) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final buzzed = _buzzed;
    final everyoneOut = _out.length == _teams;
    return ListView(
      padding: context.pageInsets(),
      children: [
        _scoreRow(context),
        const SizedBox(height: 8),
        Text(l10n.quizQuestionNumber(_index + 1, _questions!.length),
            textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(FamilyQuizScreen.question(l10n, _language, question),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            for (var t = 0; t < _teams; t++)
              _Buzzer(
                colour: FamilyQuiz.teams[t],
                label: l10n.quizTeamTurn(FamilyQuiz.teams[t].word(_language)),
                lit: buzzed == t,
                enabled: buzzed == null && !_out.contains(t),
                onTap: () => _buzz(t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (buzzed != null || everyoneOut)
          Text(
              l10n.quizAnswer(
                  FamilyQuizScreen.answer(l10n, _language, question)),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (buzzed != null)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.green.shade700),
                  onPressed: () => _judge(true),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.quizRight),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: theme.colorScheme.error),
                  onPressed: () => _judge(false),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.quizWrong),
                ),
              ),
            ],
          )
        else
          Center(
            child: TextButton.icon(
              onPressed: () => _show(_index + 1),
              icon: const Icon(Icons.skip_next),
              label: Text(l10n.quizSkip),
            ),
          ),
      ],
    );
  }

  Widget _end(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final best = _scores.fold(0, math.max);
    final winners = [
      for (var t = 0; t < _scores.length; t++)
        if (_scores[t] == best) t,
    ];
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.emoji_events_outlined, size: 88, color: Colors.amber),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            winners.length == 1
                ? l10n.quizWinner(
                    FamilyQuiz.teams[winners.single].word(_language))
                : l10n.quizDraw,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        _scoreRow(context),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => setState(() => _questions = null),
            icon: const Icon(Icons.replay),
            label: Text(l10n.quizPlayAgain),
          ),
        ),
      ],
    );
  }
}

class _Buzzer extends StatelessWidget {
  const _Buzzer({
    required this.colour,
    required this.label,
    required this.lit,
    required this.enabled,
    required this.onTap,
  });

  final LearnColour colour;
  final String label;
  final bool lit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = LightColor.fromHex(colour.hex).toColor();
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled || lit ? color : color.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: lit ? Colors.white : Colors.transparent, width: 6),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Icon(lit ? Icons.campaign : Icons.touch_app_outlined,
                size: 40,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white),
          ),
        ),
      ),
    );
  }
}
