import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';

/// Basic control of rooms and zones: on/off, brightness and the scenes
/// saved in the Hue app.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.roomsAndZones)),
      body: ListenableBuilder(
        listenable: bridge,
        builder: (context, _) {
          final home = bridge.home;
          final client = bridge.client;
          if (home == null || client == null) {
            return Center(child: Text(l10n.noBridgeConnected));
          }
          return RefreshIndicator(
            onRefresh: bridge.refresh,
            child: ListView(
              padding: context.pageInsets(),
              children: [
                if (home.rooms.isNotEmpty) _Header(l10n.rooms),
                for (final room in home.rooms)
                  _GroupTile(
                    key: ValueKey(room.id),
                    group: room,
                    home: home,
                    client: client,
                    onChanged: bridge.refresh,
                  ),
                if (home.zones.isNotEmpty) _Header(l10n.zones),
                for (final zone in home.zones)
                  _GroupTile(
                    key: ValueKey(zone.id),
                    group: zone,
                    home: home,
                    client: client,
                    onChanged: bridge.refresh,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _GroupTile extends StatefulWidget {
  const _GroupTile({
    required this.group,
    required this.home,
    required this.client,
    required this.onChanged,
    super.key,
  });

  final HueGroup group;
  final HueHome home;
  final HueBridgeClient client;
  final Future<void> Function() onChanged;

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  late bool _on;
  late double _brightness;

  @override
  void initState() {
    super.initState();
    _syncFromHome();
  }

  @override
  void didUpdateWidget(_GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.home != widget.home) {
      _syncFromHome();
    }
  }

  void _syncFromHome() {
    final lights = [
      for (final id in widget.group.lightIds)
        if (widget.home.lights[id] case final light?) light,
    ];
    _on = lights.any((l) => l.isOn);
    final dimmable = lights.where((l) => l.isOn && l.brightness != null);
    _brightness = dimmable.isEmpty
        ? 100
        : dimmable.map((l) => l.brightness!).reduce((a, b) => a + b) /
            dimmable.length;
  }

  Future<void> _send(HueLightCommand command) => _apply(
        () => widget.client
            .setGroupedLight(widget.group.groupedLightId!, command),
        enabled: widget.group.groupedLightId != null,
        failure: (l10n) => l10n.couldNotUpdate(widget.group.name),
      );

  Future<void> _recall(HueScene scene) => _apply(
        () => widget.client.recallScene(scene.id),
        failure: (l10n) => l10n.couldNotActivateScene(scene.name),
      );

  Future<void> _apply(
    Future<void> Function() command, {
    bool enabled = true,
    required String Function(AppLocalizations l10n) failure,
  }) async {
    if (!enabled) {
      return;
    }
    try {
      await command();
      // Give the bridge a moment to apply the change before reading back.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await widget.onChanged();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure(context.l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scenes = widget.home.scenesOf(widget.group.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(widget.group.name),
              subtitle: Text(l10n.lightCount(widget.group.lightIds.length)),
              value: _on,
              onChanged: widget.group.groupedLightId == null
                  ? null
                  : (value) {
                      setState(() => _on = value);
                      _send(HueLightCommand(on: value));
                    },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                value: _brightness.clamp(1, 100),
                min: 1,
                max: 100,
                onChanged: _on && widget.group.groupedLightId != null
                    ? (value) => setState(() => _brightness = value)
                    : null,
                onChangeEnd: (value) =>
                    _send(HueLightCommand(brightness: value)),
              ),
            ),
            if (scenes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.hueScenes, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final scene in scenes)
                          ChoiceChip(
                            label: Text(scene.name),
                            selected: scene.isActive,
                            onSelected: (_) => _recall(scene),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
