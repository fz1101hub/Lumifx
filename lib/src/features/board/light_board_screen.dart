import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../learn/colour_words.dart';
import 'light_board.dart';

/// The light board: the lamps of a room on a map, painted with a finger;
/// each lamp takes the colour passed over it, at once.
class LightBoardScreen extends StatefulWidget {
  const LightBoardScreen({super.key});

  @override
  State<LightBoardScreen> createState() => _LightBoardScreenState();
}

class _LightBoardScreenState extends State<LightBoardScreen> {
  String? _room;

  /// The paint in hand; null is off.
  String? _paint = LearnColour.red.hex;

  /// What each lamp was painted, null when switched off.
  final _painted = <String, String?>{};
  var _stopped = false;

  Future<void> _paintLamp(HueLight light) async {
    final scope = AppScope.of(context);
    final client = scope.bridge.client;
    final paint = _paint;
    if (client == null ||
        (_painted.containsKey(light.id) && _painted[light.id] == paint)) {
      return;
    }
    setState(() => _painted[light.id] = paint);
    unawaited(HapticFeedback.selectionClick());
    if (!_stopped) {
      // An effect playing would paint over the board.
      _stopped = true;
      if (scope.playback.status != PlaybackStatus.idle) {
        await scope.playback.stop(restore: false);
      }
    }
    try {
      await client.setLight(
        light.id,
        paint == null
            ? const HueLightCommand(on: false)
            : HueLightCommand.forLight(light, LightColor.fromHex(paint), 1,
                transition: Duration.zero),
      );
    } on Object catch (error) {
      debugPrint('Light board: $error');
    }
  }

  Future<void> _fill(List<HueLight> lights) async {
    for (final light in lights) {
      await _paintLamp(light);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final home = scope.bridge.home;
    final rooms = [
      for (final group in home?.groups ?? const <HueGroup>[])
        if (group.lightIds.isNotEmpty) group,
    ];
    final room =
        rooms.where((g) => g.id == _room).firstOrNull ?? rooms.firstOrNull;
    final lights = [
      for (final id in room?.lightIds ?? const <String>[])
        if (home?.lights[id] case final light?) light,
    ];
    final layout = boardLayout([for (final l in lights) l.id], home);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lightBoard)),
      body: scope.bridge.client == null || home == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : ListView(
              padding: context.pageInsets(),
              children: [
                Text(l10n.lightBoardDescription,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final group in rooms)
                      ChoiceChip(
                        label: Text(group.name),
                        selected: group.id == room?.id,
                        onSelected: (_) => setState(() => _room = group.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final colour in [...LearnColour.values, null])
                      _PaintPot(
                        color: colour?.hex,
                        label: colour == null
                            ? l10n.lightBoardOff
                            : colour.word(language),
                        selected: _paint == colour?.hex,
                        onTap: () => setState(() => _paint = colour?.hex),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lights.isEmpty)
                  Text(l10n.lightBoardNoLights,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge)
                else ...[
                  AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        void touch(Offset at) {
                          final id = lampAt(
                              layout, at.dx / size.width, at.dy / size.height);
                          final light = home.lights[id];
                          if (light != null) {
                            unawaited(_paintLamp(light));
                          }
                        }

                        return GestureDetector(
                          onPanStart: (d) => touch(d.localPosition),
                          onPanUpdate: (d) => touch(d.localPosition),
                          onTapDown: (d) => touch(d.localPosition),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF15151F),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Stack(
                              children: [
                                for (final light in lights)
                                  if (layout[light.id] case final spot?)
                                    Positioned(
                                      left: spot.x * size.width - 32,
                                      top: spot.y * size.height - 32,
                                      child: _Lamp(
                                        name: light.name,
                                        color: _painted.containsKey(light.id)
                                            ? _painted[light.id]
                                            : null,
                                        painted: _painted.containsKey(light.id),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _fill(lights),
                    icon: const Icon(Icons.format_color_fill),
                    label: Text(l10n.lightBoardFill),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PaintPot extends StatelessWidget {
  const _PaintPot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paint = color;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paint == null
                  ? Colors.black
                  : LightColor.fromHex(paint).toColor(),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                width: selected ? 4 : 1,
              ),
            ),
            child: paint == null
                ? const Icon(Icons.power_settings_new, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.name, required this.color, required this.painted});

  final String name;
  final String? color;
  final bool painted;

  @override
  Widget build(BuildContext context) {
    final paint = color;
    final shown = paint == null
        ? (painted ? Colors.black : Colors.white24)
        : LightColor.fromHex(paint).toColor();
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shown,
                border: Border.all(color: Colors.white54),
                boxShadow: [
                  if (paint != null)
                    BoxShadow(color: shown, blurRadius: 18, spreadRadius: 2),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
