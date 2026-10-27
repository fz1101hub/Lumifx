import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../learn/colour_mixing.dart';
import '../learn/colour_words.dart';
import '../learn/farm.dart';

/// Who the questions are for.
enum QuizPack { little, kids, family }

/// A question of the family quiz, made up on the phone so it is right in
/// every language: the words come from the app's own.
sealed class QuizQuestion {
  const QuizQuestion();
}

/// "Who says moo?"
class SoundQuestion extends QuizQuestion {
  const SoundQuestion(this.animal);
  final FarmAnimal animal;
}

/// "What colour is the light?", the room in that colour.
class ColourQuestion extends QuizQuestion {
  const ColourQuestion(this.colour);
  final LearnColour colour;
}

/// "How much is 7 plus 5?" (or minus, or times).
class SumQuestion extends QuizQuestion {
  const SumQuestion(this.a, this.b, this.op);
  final int a;
  final int b;
  final SumOp op;

  int get answer => switch (op) {
        SumOp.plus => a + b,
        SumOp.minus => a - b,
        SumOp.times => a * b,
      };
}

enum SumOp { plus, minus, times }

/// "What colour do red and yellow make?"
class MixQuestion extends QuizQuestion {
  const MixQuestion(this.a, this.b, this.mix);
  final LearnColour a;
  final LearnColour b;
  final LearnColour mix;
}

abstract final class FamilyQuiz {
  static const minTeams = 2;
  static const maxTeams = 4;
  static const questions = 10;

  /// [count] questions for [pack], never the same twice in a row.
  static List<QuizQuestion> make(QuizPack pack, math.Random random,
      {int count = questions}) {
    QuizQuestion sound() => SoundQuestion(
        FarmAnimal.values[random.nextInt(FarmAnimal.values.length)]);
    QuizQuestion colour() => ColourQuestion(
        LearnColour.values[random.nextInt(LearnColour.values.length)]);
    QuizQuestion mix() {
      final (a, b, made) = paintMixes[random.nextInt(paintMixes.length)];
      return MixQuestion(a, b, made);
    }

    QuizQuestion plus(int most) {
      final a = random.nextInt(most) + 1;
      return SumQuestion(a, random.nextInt(most - a + 1), SumOp.plus);
    }

    QuizQuestion minus(int most) {
      final a = random.nextInt(most) + 1;
      return SumQuestion(a, random.nextInt(a + 1), SumOp.minus);
    }

    QuizQuestion times() =>
        SumQuestion(random.nextInt(9) + 2, random.nextInt(9) + 2, SumOp.times);

    final makers = switch (pack) {
      QuizPack.little => [sound, colour, () => plus(5)],
      QuizPack.kids => [sound, mix, () => plus(20), () => minus(20)],
      QuizPack.family => [mix, times, () => minus(100), () => plus(100)],
    };
    final made = <QuizQuestion>[];
    var last = -1;
    while (made.length < count) {
      var kind = random.nextInt(makers.length);
      if (kind == last) {
        kind = (kind + 1) % makers.length;
      }
      last = kind;
      made.add(makers[kind]());
    }
    return made;
  }

  /// The team colours, in turn order.
  static const teams = [
    LearnColour.red,
    LearnColour.blue,
    LearnColour.green,
    LearnColour.yellow,
  ];

  static const _prefix = '${LightingEffect.generatedPrefix}quiz:';

  /// The quiz show's lights between questions: a dim purple studio.
  static LightingEffect studio(String name) => LightingEffect(
        id: '${_prefix}studio',
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(minutes: 2),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(minutes: 2),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#5B2EFF', '#1A4BFF', '#D23CFF'],
              'brightnessMin': 0.25,
              'brightnessMax': 0.45,
              'speed': 0.05,
            },
          ),
        ],
      );

  /// The winners' colour, bursting.
  static LightingEffect winner(String name, LearnColour team) => LightingEffect(
        id: '${_prefix}winner:${team.name}',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: const Duration(seconds: 20),
        events: [
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(seconds: 20),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': [team.hex, '#FFF4E5', team.hex],
              'brightnessMin': 0.6,
              'brightnessMax': 1.0,
              'speed': 0.3,
            },
          ),
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(seconds: 4),
            type: EffectEventTypes.surprise,
            parameters: {'color': team.hex, 'count': 4},
          ),
        ],
      );

  /// Whether [effect] belongs to the quiz.
  static bool isQuiz(LightingEffect effect) => effect.id.startsWith(_prefix);
}
