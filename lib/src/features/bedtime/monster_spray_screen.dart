import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'monster_spray.dart';

enum _Stage { intro, hunting, safe }

/// Before sleep: chase the monsters out of the room with a spray, one
/// puff at a time, then leave a guardian light on.
class MonsterSprayScreen extends StatefulWidget {
  const MonsterSprayScreen({this.playing, super.key});

  /// What is already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  @override
  State<MonsterSprayScreen> createState() => _MonsterSprayScreenState();
}

class _MonsterSprayScreenState extends State<MonsterSprayScreen> {
  var _hunt = MonsterHunt();
  late var _stage = switch (widget.playing) {
    final effect? when MonsterHunt.isGuardian(effect) => _Stage.safe,
    final effect? when MonsterHunt.isHunting(effect) => _Stage.hunting,
    _ => _Stage.intro,
  };
  var _minutes = 30;
  var _generation = 0;

  static const _colors = [
    Color(0xFF8BC34A),
    Color(0xFFBA68C8),
    Color(0xFF4FC3F7),
    Color(0xFFFF8A65),
    Color(0xFFFFD54F),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back from the mini-player: the chips show the timer already set.
    final minutes = AppScope.of(context).playback.sleepTimer?.inMinutes;
    if (_stage == _Stage.safe &&
        _generation == 0 &&
        MonsterHunt.guardianMinutes.contains(minutes)) {
      _minutes = minutes!;
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _play(LightingEffect effect) async {
    final playback = AppScope.of(context).playback;
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _start() async {
    _generation++;
    setState(() {
      _hunt = MonsterHunt();
      _stage = _Stage.hunting;
    });
    final playback = AppScope.of(context).playback;
    playback.setSleepTimer(null);
    await _play(MonsterHunt.hiding(context.l10n.monsterSpray));
  }

  Future<void> _spray() async {
    if (_stage != _Stage.hunting || _hunt.isDone) {
      return;
    }
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    unawaited(HapticFeedback.mediumImpact());
    scope.playback.flash(LightColor.fromHex(MonsterHunt.sprayColor),
        length: const Duration(milliseconds: 700));
    setState(_hunt.spray);
    if (!_hunt.isDone) {
      return;
    }
    final generation = ++_generation;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _stage = _Stage.safe);
    scope.playback.flash(const LightColor(1, 0.9, 0.6),
        length: const Duration(milliseconds: 1200));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || generation != _generation) {
      return;
    }
    await _play(MonsterHunt.guardian(l10n.guardianLight));
    scope.playback.setSleepTimer(Duration(minutes: _minutes));
  }

  void _setMinutes(int minutes) {
    setState(() => _minutes = minutes);
    final playback = AppScope.of(context).playback;
    if (MonsterHunt.isGuardian(playback.effect) &&
        playback.status != PlaybackStatus.idle) {
      playback.setSleepTimer(Duration(minutes: minutes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.monsterSpray)),
      body: switch (_stage) {
        _Stage.intro => _intro(context),
        _Stage.hunting => _hunting(context),
        _Stage.safe => _safe(context),
      },
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final color in _colors) _Monster(color: color, gone: false),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.monsterSprayDescription, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.timerStart),
        ),
      ],
    );
  }

  Widget _hunting(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.monstersLeft(_hunt.left),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _hunt.count; i++)
                _Monster(
                  color: _colors[i % _colors.length],
                  // The first ones go first.
                  gone: i < _hunt.count - _hunt.left,
                ),
            ],
          ),
          const SizedBox(height: 40),
          Center(
            child: SizedBox.square(
              dimension: 180,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor:
                      LightColor.fromHex(MonsterHunt.sprayColor).toColor(),
                  foregroundColor: Colors.black87,
                ),
                onPressed: _hunt.isDone ? null : _spray,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sanitizer_outlined, size: 64),
                    const SizedBox(height: 8),
                    Text(l10n.monsterSprayButton,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safe(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Icon(Icons.shield_moon_outlined,
            size: 72, color: Colors.amber.shade300),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.monstersGone,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.guardianLightDescription,
            textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        Text(l10n.guardianLightFor, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in MonsterHunt.guardianMinutes)
              ChoiceChip(
                label: Text(l10n.sleepTimerMinutes(minutes)),
                selected: _minutes == minutes,
                onSelected: (_) => _setMinutes(minutes),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.sanitizer_outlined),
              label: Text(l10n.monsterSprayAgain),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      ],
    );
  }
}

/// A round little monster with big eyes, who shrinks away when sprayed.
class _Monster extends StatelessWidget {
  const _Monster({required this.color, required this.gone});

  final Color color;
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450);
    Widget eye() => Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: Colors.black87, shape: BoxShape.circle),
          ),
        );
    return ExcludeSemantics(
      child: AnimatedOpacity(
        duration: duration,
        opacity: gone ? 0 : 1,
        child: AnimatedScale(
          duration: duration,
          scale: gone ? 0.2 : 1,
          child: Container(
            width: 56,
            height: 60,
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [eye(), const SizedBox(width: 4), eye()],
                ),
                const SizedBox(height: 6),
                Container(
                  width: 18,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
