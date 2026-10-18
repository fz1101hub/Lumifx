import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../calm/breathing_screen.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_palette.dart';
import '../effects/playback_controller.dart';
import '../fun/simon_screen.dart';
import '../library/effect_library.dart';
import '../learn/colour_mixing_screen.dart';
import '../learn/colour_words_screen.dart';
import '../learn/counting_screen.dart';
import '../library/preferences_controller.dart';
import '../music_box/light_piano_screen.dart';

/// Games kids mode can offer besides the effects: nothing on them leads
/// to the rest of the app.
enum KidsActivity {
  piano(Icons.piano_outlined),
  counting(Icons.filter_9_plus_outlined),
  colours(Icons.translate),
  mixing(Icons.palette_outlined),
  simon(Icons.psychology_outlined),
  breathing(Icons.spa_outlined);

  const KidsActivity(this.icon);

  final IconData icon;

  String title(AppLocalizations l10n) => switch (this) {
        piano => l10n.piano,
        counting => l10n.countLights,
        colours => l10n.colourWords,
        mixing => l10n.colourMixing,
        simon => l10n.gameSimon,
        breathing => l10n.breathe,
      };

  Widget screen() => switch (this) {
        piano => const LightPianoScreen(),
        counting => const CountingScreen(),
        colours => const ColourWordsScreen(),
        mixing => const ColourMixingScreen(),
        simon => const SimonScreen(),
        breathing => const BreathingScreen(),
      };

  /// The games a grown-up kept (all of them until one chooses).
  static List<KidsActivity> chosen(PreferencesController preferences) {
    final names = preferences.kidsActivities;
    return [
      for (final activity in values)
        if (names == null || names.contains(activity.name)) activity,
    ];
  }
}

/// The route name of kids mode: the mini-player stays away from it.
const kidsModeRouteName = '/kids';

/// Whether [routeName] is kids mode or one of its games.
bool isKidsModeRoute(String? routeName) =>
    routeName == kidsModeRouteName ||
    (routeName?.startsWith('$kidsModeRouteName/') ?? false);

/// Effects fit for kids mode: nothing that flashes fast, nothing that
/// needs the microphone or the camera.
bool kidsSafe(LightingEffect effect) =>
    !effect.hasRapidFlashes &&
    (effect.kind == EffectKind.scene || effect.kind == EffectKind.story);

/// What kids mode offers before a grown-up chooses: the gentle scenes
/// and stories, eight at most.
List<String> defaultKidsEffects(EffectLibrary library) => [
      for (final kind in const [EffectKind.story, EffectKind.scene])
        for (final effect in library.ofKind(kind))
          if (kidsSafe(effect) && !effect.isGenerated) effect.id,
    ].take(8).toList();

/// Whether [effect] may start now, from a link, the voice or a Hue
/// button: anything outside kids mode; in kids mode only the gentle
/// effects a grown-up chose.
bool kidsModeAllows(
  PreferencesController preferences,
  EffectLibrary library,
  LightingEffect effect,
) {
  if (!preferences.kidsLocked) {
    return true;
  }
  final ids = preferences.kidsEffects ?? defaultKidsEffects(library);
  return kidsSafe(effect) && ids.contains(effect.id);
}

/// Whether bedtime (its [story], then the goodnight glow) may start: in
/// kids mode, only when both are among the effects a grown-up chose.
bool kidsModeAllowsBedtime(
  PreferencesController preferences,
  EffectLibrary library,
  LightingEffect story,
) {
  if (!preferences.kidsLocked) {
    return true;
  }
  final glow = library.byId(PlaybackController.bedtimeGlowId);
  return kidsModeAllows(preferences, library, story) &&
      glow != null &&
      kidsModeAllows(preferences, library, glow);
}

/// Opens kids mode, which stays on (even after a restart) until a grown-up
/// answers the question to leave.
Future<void> openKidsMode(NavigatorState navigator) => navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kidsModeRouteName),
        fullscreenDialog: true,
        builder: (_) => const KidsModeScreen(),
      ),
    );

/// For grown-ups: which effects kids mode offers, and the way in.
class KidsSetupScreen extends StatelessWidget {
  const KidsSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    final library = scope.library;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kidsMode)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final chosen =
              (preferences.kidsEffects ?? defaultKidsEffects(library)).toSet();
          final candidates = [
            for (final kind in const [EffectKind.story, EffectKind.scene])
              for (final effect in library.ofKind(kind))
                if (!effect.isGenerated) effect,
          ];
          return ListView(
            padding: context.pageInsets(bottom: 96),
            children: [
              Text(l10n.kidsModeDescription, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(l10n.kidsModeTip, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: chosen.isEmpty
                    ? null
                    : () async {
                        await preferences.setKidsLocked(true);
                        if (context.mounted) {
                          await openKidsMode(Navigator.of(context));
                        }
                      },
                icon: const Icon(Icons.child_care),
                label: Text(l10n.kidsModeStart),
              ),
              const SizedBox(height: 24),
              Text(l10n.kidsModeActivities, style: theme.textTheme.titleMedium),
              for (final activity in KidsActivity.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(activity.icon),
                  value: KidsActivity.chosen(preferences).contains(activity),
                  title: Text(activity.title(l10n)),
                  onChanged: (on) => preferences.setKidsActivities([
                    for (final a in KidsActivity.chosen(preferences))
                      if (a != activity) a.name,
                    if (on == true) activity.name,
                  ]),
                ),
              const SizedBox(height: 16),
              Text(l10n.kidsModeChoose, style: theme.textTheme.titleMedium),
              for (final effect in candidates)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: kidsSafe(effect) && chosen.contains(effect.id),
                  title: Text(l10n.effectName(effect)),
                  subtitle:
                      kidsSafe(effect) ? null : Text(l10n.kidsModeFlashing),
                  onChanged: kidsSafe(effect)
                      ? (on) => preferences.setKidsEffects([
                            for (final id in chosen)
                              if (id != effect.id) id,
                            if (on == true) effect.id,
                          ])
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Big buttons, only the chosen effects, a big stop; no way back to the
/// rest of the app without a grown-up.
class KidsModeScreen extends StatelessWidget {
  const KidsModeScreen({super.key});

  Future<void> _play(PlaybackController playback, LightingEffect effect) async {
    unawaited(HapticFeedback.selectionClick());
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _exit(BuildContext context) async {
    final preferences = AppScope.of(context).preferences;
    final navigator = Navigator.of(context);
    final allowed = await showDialog<bool>(
      context: context,
      builder: (_) => const GrownUpGate(),
    );
    if (allowed == true) {
      await preferences.setKidsLocked(false);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final playback = scope.playback;
    final ids =
        scope.preferences.kidsEffects ?? defaultKidsEffects(scope.library);
    final effects = [
      for (final id in ids)
        if (scope.library.byId(id) case final effect? when kidsSafe(effect))
          effect,
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.kidsMode),
          actions: [
            IconButton(
              tooltip: l10n.kidsModeExit,
              icon: const Icon(Icons.lock_outline),
              onPressed: () => _exit(context),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([playback, scope.preferences]),
          builder: (context, _) {
            final playing = playback.status != PlaybackStatus.idle;
            final activities = KidsActivity.chosen(scope.preferences);
            return Column(
              children: [
                if (activities.isNotEmpty)
                  // One row that scrolls sideways, so the effects keep
                  // the screen.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
                    child: Row(
                      children: [
                        for (final activity in activities)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 56)),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: RouteSettings(
                                      name: '$kidsModeRouteName/'
                                          '${activity.name}'),
                                  builder: (_) => activity.screen(),
                                ),
                              ),
                              icon: Icon(activity.icon),
                              label: Text(activity.title(l10n)),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: context.isWide ? 4 : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      for (final effect in effects)
                        _KidsTile(
                          effect: effect,
                          playing: playing && playback.effect.id == effect.id,
                          onTap: () => _play(playback, effect),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(72),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      onPressed: playing ? playback.stop : null,
                      icon: const Icon(Icons.stop_rounded, size: 36),
                      label: Text(l10n.stop),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KidsTile extends StatelessWidget {
  const _KidsTile({
    required this.effect,
    required this.playing,
    required this.onTap,
  });

  final LightingEffect effect;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = effectPalette(effect);
    return Semantics(
      button: true,
      selected: playing,
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.length >= 2
                    ? colors
                    : [colors.firstOrNull ?? Colors.indigo, Colors.black],
              ),
              border:
                  playing ? Border.all(color: Colors.white, width: 6) : null,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.l10n.effectName(effect),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black87),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sum too hard for small children, to let a grown-up out (or confirm
/// something only a grown-up may do, under [title]).
class GrownUpGate extends StatefulWidget {
  const GrownUpGate({this.title, super.key});

  final String? title;

  /// Whether a grown-up answered.
  static Future<bool> ask(BuildContext context, {String? title}) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => GrownUpGate(title: title),
      ) ==
      true;

  @override
  State<GrownUpGate> createState() => _GrownUpGateState();
}

class _GrownUpGateState extends State<GrownUpGate> {
  final _random = math.Random();
  late final int _a = 11 + _random.nextInt(9);
  late final int _b = 6 + _random.nextInt(9);
  final _answer = TextEditingController();
  var _wrong = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_answer.text.trim()) == _a + _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l10n.kidsModeExit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title == null
              ? l10n.kidsGateQuestion(_a, _b)
              : l10n.grownUpQuestion(_a, _b)),
          TextField(
            controller: _answer,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              errorText: _wrong ? l10n.kidsGateWrong : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _check,
          child: Text(
              widget.title == null ? l10n.kidsGateOk : l10n.grownUpConfirm),
        ),
      ],
    );
  }
}
