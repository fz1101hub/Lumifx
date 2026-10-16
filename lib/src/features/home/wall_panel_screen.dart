import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/screen_wake.dart';
import '../common/app_text.dart';
import '../effects/effect_palette.dart';
import '../effects/effect_player_screen.dart';
import '../effects/playback_controller.dart';
import '../rooms/rooms_screen.dart';

/// A tablet on the wall: the time, what plays, every room with its switch,
/// brightness and Hue scenes, and the favourites a tap away. The screen
/// stays on and dims after two minutes without a touch.
class WallPanelScreen extends StatefulWidget {
  const WallPanelScreen({
    this.screenWake = const WakelockScreenWake(holder: 'wall_panel'),
    this.dimAfter = const Duration(minutes: 2),
    super.key,
  });

  final ScreenWake screenWake;
  final Duration dimAfter;

  @override
  State<WallPanelScreen> createState() => _WallPanelScreenState();
}

class _WallPanelScreenState extends State<WallPanelScreen> {
  late final Timer _clock;
  Timer? _dimTimer;
  bool _dimmed = false;
  late DateTime _now;
  DateTime Function() _today = DateTime.now;

  @override
  void initState() {
    super.initState();
    unawaited(widget.screenWake.keepOn(true));
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() => _now = _today());
      }
    });
    _wake();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _today = AppScope.of(context).clock;
    _now = _today();
  }

  void _wake() {
    _dimTimer?.cancel();
    if (_dimmed) {
      setState(() => _dimmed = false);
    }
    _dimTimer = Timer(widget.dimAfter, () {
      if (mounted) {
        setState(() => _dimmed = true);
      }
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _dimTimer?.cancel();
    unawaited(widget.screenWake.keepOn(false));
    super.dispose();
  }

  Future<void> _play(LightingEffect effect) async {
    final playback = AppScope.of(context).playback;
    if (effect.hasRapidFlashes && !await confirmFlashingLights(context)) {
      return;
    }
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _wake(),
        child: Stack(
          children: [
            SafeArea(
              child: ListenableBuilder(
                listenable: Listenable.merge(
                    [scope.bridge, scope.preferences, scope.playback]),
                builder: (context, _) {
                  final home = scope.bridge.home;
                  final client = scope.bridge.client;
                  final favorites = [
                    for (final id in scope.preferences.favorites.isNotEmpty
                        ? scope.preferences.favorites
                        : scope.preferences.recents)
                      if (scope.library.byId(id) case final effect?) effect,
                  ];
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  MaterialLocalizations.of(context)
                                      .formatTimeOfDay(
                                    TimeOfDay.fromDateTime(_now),
                                    alwaysUse24HourFormat:
                                        MediaQuery.alwaysUse24HourFormatOf(
                                            context),
                                  ),
                                  style: theme.textTheme.displayLarge,
                                ),
                                Text(
                                  DateFormat.MMMMEEEEd(locale).format(_now),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.close,
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      // What plays shows in the app's mini-player below.
                      if (favorites.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(l10n.favorites,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final effect in favorites.take(8))
                              _EffectButton(
                                effect: effect,
                                onTap: () => _play(effect),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (home == null || client == null)
                        Text(l10n.noBridgeConnected)
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = (constraints.maxWidth / 380)
                                .floor()
                                .clamp(1, 3);
                            final width =
                                (constraints.maxWidth - (columns - 1) * 12) /
                                    columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final group in home.groups)
                                  if (group.lightIds.isNotEmpty)
                                    SizedBox(
                                      width: width,
                                      child: GroupTile(
                                        key: ValueKey(group.id),
                                        group: group,
                                        home: home,
                                        client: client,
                                        onChanged: scope.bridge.refresh,
                                      ),
                                    ),
                              ],
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
            // Dimmed: a dark veil; the first touch only wakes the panel.
            IgnorePointer(
              ignoring: !_dimmed,
              child: AnimatedOpacity(
                opacity: _dimmed ? 0.85 : 0,
                duration: const Duration(seconds: 1),
                child: GestureDetector(
                  onTap: _wake,
                  child: Container(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectButton extends StatelessWidget {
  const _EffectButton({required this.effect, required this.onTap});

  final LightingEffect effect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = effectPalette(effect);
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: 160,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: colors.length > 1 ? colors : [...colors, ...colors],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
              stops: [0.25, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                context.l10n.effectName(effect),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
