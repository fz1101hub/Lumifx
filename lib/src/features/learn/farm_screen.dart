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
import 'farm.dart';

enum _Mode { listen, guess }

/// The light farm: tap an animal, the room takes its colour and the voice
/// makes its sound; or hear a sound and find who makes it.
class FarmScreen extends StatefulWidget {
  const FarmScreen({this.seed, super.key});

  /// Fixes the quiz (tests).
  final int? seed;

  static String nameOf(AppLocalizations l10n, FarmAnimal animal) =>
      switch (animal) {
        FarmAnimal.cow => l10n.farmAnimalCow,
        FarmAnimal.pig => l10n.farmAnimalPig,
        FarmAnimal.duck => l10n.farmAnimalDuck,
        FarmAnimal.frog => l10n.farmAnimalFrog,
        FarmAnimal.cat => l10n.farmAnimalCat,
        FarmAnimal.dog => l10n.farmAnimalDog,
        FarmAnimal.horse => l10n.farmAnimalHorse,
        FarmAnimal.rooster => l10n.farmAnimalRooster,
      };

  static String soundOf(AppLocalizations l10n, FarmAnimal animal) =>
      switch (animal) {
        FarmAnimal.cow => l10n.farmSoundCow,
        FarmAnimal.pig => l10n.farmSoundPig,
        FarmAnimal.duck => l10n.farmSoundDuck,
        FarmAnimal.frog => l10n.farmSoundFrog,
        FarmAnimal.cat => l10n.farmSoundCat,
        FarmAnimal.dog => l10n.farmSoundDog,
        FarmAnimal.horse => l10n.farmSoundHorse,
        FarmAnimal.rooster => l10n.farmSoundRooster,
      };

  static IconData iconOf(FarmAnimal animal) => switch (animal) {
        FarmAnimal.cow => Icons.grass,
        FarmAnimal.pig => Icons.savings_outlined,
        FarmAnimal.duck => Icons.water,
        FarmAnimal.frog => Icons.eco_outlined,
        FarmAnimal.cat => Icons.pets,
        FarmAnimal.dog => Icons.cruelty_free_outlined,
        FarmAnimal.horse => Icons.bedroom_baby_outlined,
        FarmAnimal.rooster => Icons.wb_sunny_outlined,
      };

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  late final _quiz =
      FarmQuiz(widget.seed == null ? null : math.Random(widget.seed));
  var _mode = _Mode.listen;
  FarmAnimal? _shown;
  bool? _right;

  static String _capitalised(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language);
    }());
  }

  Future<void> _show(FarmAnimal animal) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    await playback.switchEffect(
        animal.effect(_capitalised(FarmScreen.nameOf(l10n, animal))));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _tap(FarmAnimal animal) async {
    final l10n = context.l10n;
    unawaited(HapticFeedback.selectionClick());
    if (_mode == _Mode.listen) {
      setState(() => _shown = animal);
      // The sound first: the light answers as it starts.
      _say(_capitalised(l10n.farmSays(
          FarmScreen.nameOf(l10n, animal), FarmScreen.soundOf(l10n, animal))));
      await _show(animal);
      return;
    }
    if (_right == true) {
      return;
    }
    if (!_quiz.answer(animal)) {
      setState(() => _right = false);
      _say(l10n.colourWordsTryAgain);
      return;
    }
    setState(() {
      _right = true;
      _shown = animal;
    });
    _say(l10n.colourWordsRight);
    await _show(animal);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted && _mode == _Mode.guess) {
      _ask();
    }
  }

  void _ask() {
    final l10n = context.l10n;
    setState(() {
      _quiz.next();
      _right = null;
    });
    _say(l10n.farmWhoSays(FarmScreen.soundOf(l10n, _quiz.target)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final animals = _mode == _Mode.guess && _quiz.choices.isNotEmpty
        ? _quiz.choices
        : FarmAnimal.values;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.farm)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.farmDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(
                value: _Mode.listen,
                icon: const Icon(Icons.hearing),
                label: Text(l10n.farmListen),
              ),
              ButtonSegment(
                value: _Mode.guess,
                icon: const Icon(Icons.quiz_outlined),
                label: Text(l10n.colourWordsQuiz),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selected) {
              setState(() => _mode = selected.first);
              if (_mode == _Mode.guess) {
                _ask();
              }
            },
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.guess && _quiz.choices.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                switch (_right) {
                  true => l10n.colourWordsRight,
                  false => l10n.colourWordsTryAgain,
                  null =>
                    l10n.farmWhoSays(FarmScreen.soundOf(l10n, _quiz.target)),
                },
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: context.isWide ? 4 : (animals.length == 3 ? 3 : 2),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              for (final animal in animals)
                _AnimalTile(
                  label: _capitalised(FarmScreen.nameOf(l10n, animal)),
                  icon: FarmScreen.iconOf(animal),
                  color: LightColor.fromHex(animal.color).toColor(),
                  selected: _shown == animal,
                  onTap: () => _tap(animal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outlineVariant,
            width: selected ? 4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: onColor),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: onColor)),
            ],
          ),
        ),
      ),
    );
  }
}
