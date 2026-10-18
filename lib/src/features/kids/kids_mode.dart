import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_palette.dart';
import '../effects/playback_controller.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';

/// The route name of kids mode: the mini-player stays away from it.
const kidsModeRouteName = '/kids';

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
      builder: (_) => const _GrownUpGate(),
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
          listenable: playback,
          builder: (context, _) {
            final playing = playback.status != PlaybackStatus.idle;
            return Column(
              children: [
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

/// A sum too hard for small children, to let a grown-up out.
class _GrownUpGate extends StatefulWidget {
  const _GrownUpGate();

  @override
  State<_GrownUpGate> createState() => _GrownUpGateState();
}

class _GrownUpGateState extends State<_GrownUpGate> {
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
      title: Text(l10n.kidsModeExit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.kidsGateQuestion(_a, _b)),
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
        FilledButton(onPressed: _check, child: Text(l10n.kidsGateOk)),
      ],
    );
  }
}
