import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_buttons.dart';
import '../../core/hue/hue_house.dart';
import '../../core/hue/hue_models.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'treasure_hunt.dart';

/// The treasure hunt: rooms chosen in order, a riddle read aloud for each,
/// the room lit as a hint, found with a tap, its motion sensor or a
/// sticker, then the golden treasure and a star.
class TreasureHuntScreen extends StatefulWidget {
  const TreasureHuntScreen({this.motion, this.sensors, this.rooms, super.key});

  /// Rooms instead of the bridge's (tests).
  final List<HueGroup>? rooms;

  /// Motion events instead of the bridge's (tests).
  final Stream<HueMotionEvent> Function()? motion;

  /// Motion sensors instead of the bridge's (tests).
  final List<HueMotionSensor>? sensors;

  static String riddle(AppLocalizations l10n, HueGroup room) =>
      switch (TreasureHunt.kindOf(room.archetype)) {
        RoomKind.living => l10n.riddleLiving,
        RoomKind.kitchen => l10n.riddleKitchen,
        RoomKind.dining => l10n.riddleDining,
        RoomKind.bedroom => l10n.riddleBedroom,
        RoomKind.kids => l10n.riddleKids,
        RoomKind.bathroom => l10n.riddleBathroom,
        RoomKind.office => l10n.riddleOffice,
        RoomKind.hallway => l10n.riddleHallway,
        RoomKind.garden => l10n.riddleGarden,
        RoomKind.other => l10n.riddleOther(room.name),
      };

  @override
  State<TreasureHuntScreen> createState() => _TreasureHuntScreenState();
}

class _TreasureHuntScreenState extends State<TreasureHuntScreen> {
  final _chosen = <HueGroup>[];
  var _sensors = const <HueMotionSensor>[];

  /// The clue being looked for; null before the start, the number of
  /// rooms once the treasure is found.
  int? _step;
  DateTime? _stepStarted;
  StreamSubscription<HueMotionEvent>? _motion;
  StreamSubscription<void>? _stickers;

  @override
  void initState() {
    super.initState();
    _stickers = TreasureHunt.stickerTaps.listen((_) => _found());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSensors());
  }

  @override
  void dispose() {
    unawaited(_motion?.cancel());
    unawaited(_stickers?.cancel());
    super.dispose();
  }

  Future<void> _loadSensors() async {
    final client = AppScope.of(context).bridge.client;
    final sensors = widget.sensors ??
        (client == null
            ? const <HueMotionSensor>[]
            : await client
                .fetchMotionSensors()
                .catchError((Object _) => <HueMotionSensor>[]));
    if (mounted) {
      setState(() => _sensors = sensors);
    }
  }

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language, style: SpeechStyle.story);
    }());
  }

  Future<void> _light(HueGroup room, String color) async {
    final client = AppScope.of(context).bridge.client;
    final grouped = room.groupedLightId;
    if (client == null || grouped == null) {
      return;
    }
    try {
      await client.setGroupedLight(
          grouped,
          HueLightCommand.fromColor(LightColor.fromHex(color), 1,
              transition: const Duration(milliseconds: 400)));
    } on Object catch (error) {
      debugPrint('Treasure hunt: $error');
    }
  }

  void _ask(int step, {String before = ''}) {
    final l10n = context.l10n;
    setState(() {
      _step = step;
      _stepStarted = DateTime.now();
    });
    _say('$before${TreasureHuntScreen.riddle(l10n, _chosen[step])}'.trim());
    _listen();
  }

  Future<void> _start() async {
    final playback = AppScope.of(context).playback;
    if (playback.status != PlaybackStatus.idle) {
      await playback.stop(restore: false);
    }
    if (mounted) {
      _ask(0);
    }
  }

  /// Watches the motion sensor named after the room being looked for.
  void _listen() {
    unawaited(_motion?.cancel());
    _motion = null;
    final step = _step;
    if (step == null || step >= _chosen.length) {
      return;
    }
    final sensor = TreasureHunt.sensorIn(_chosen[step].name, _sensors);
    if (sensor == null) {
      return;
    }
    final client = AppScope.of(context).bridge.client;
    final events = widget.motion?.call() ?? client?.motionEvents();
    _motion = events?.listen(
      (event) {
        final started = _stepStarted;
        // Someone still in the last room must not count at once.
        if (event.motion &&
            event.sensorId == sensor &&
            started != null &&
            DateTime.now().difference(started) > const Duration(seconds: 2)) {
          unawaited(_found());
        }
      },
      onError: (Object _) {},
    );
  }

  Future<void> _found() async {
    final step = _step;
    if (step == null || step >= _chosen.length || !mounted) {
      return;
    }
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    unawaited(HapticFeedback.heavyImpact());
    unawaited(_light(_chosen[step], TreasureHunt.found));
    if (step + 1 < _chosen.length) {
      _ask(step + 1, before: '${l10n.treasureWellDone} ');
      return;
    }
    unawaited(_motion?.cancel());
    _motion = null;
    setState(() => _step = _chosen.length);
    _say(l10n.treasureTreasure);
    final today = scope.clock();
    scope.preferences.earnStar('${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}:treasure');
    final playback = scope.playback;
    playback.setSleepTimer(null);
    await playback.switchEffect(TreasureHunt.treasure(l10n.treasureHunt));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final step = _step;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.treasureHunt)),
      body: scope.bridge.client == null || scope.bridge.home == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : step == null
              ? _setup(context)
              : step >= _chosen.length
                  ? _treasure(context)
                  : _clue(context, step),
    );
  }

  Widget _setup(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rooms = widget.rooms ??
        AppScope.of(context).bridge.home?.rooms ??
        const <HueGroup>[];
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.treasureHuntDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.treasureRooms, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final room in rooms)
              FilterChip(
                avatar: _chosen.contains(room)
                    ? CircleAvatar(
                        child: Text('${_chosen.indexOf(room) + 1}'),
                      )
                    : null,
                showCheckmark: false,
                label: Text(room.name),
                selected: _chosen.contains(room),
                onSelected: (on) => setState(() {
                  if (!on) {
                    _chosen.remove(room);
                  } else if (_chosen.length < TreasureHunt.maxSteps) {
                    _chosen.add(room);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed:
              _chosen.length >= TreasureHunt.minSteps ? () => _start() : null,
          icon: const Icon(Icons.explore_outlined),
          label: Text(l10n.treasureStart),
        ),
      ],
    );
  }

  Widget _clue(BuildContext context, int step) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final room = _chosen[step];
    final riddle = TreasureHuntScreen.riddle(l10n, room);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.treasureStep(step + 1, _chosen.length),
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Semantics(
              liveRegion: true,
              child: Text(riddle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _say(riddle),
              icon: const Icon(Icons.replay),
              label: Text(l10n.treasureReadAgain),
            ),
            OutlinedButton.icon(
              onPressed: () => _light(room, TreasureHunt.gold),
              icon: const Icon(Icons.flashlight_on_outlined),
              label: Text(l10n.treasureHint),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: _found,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.treasureFound),
        ),
      ],
    );
  }

  Widget _treasure(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.diamond_outlined, size: 96, color: Colors.amber),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(l10n.treasureTreasure,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _step = null),
            icon: const Icon(Icons.replay),
            label: Text(l10n.treasureStart),
          ),
        ),
      ],
    );
  }
}
