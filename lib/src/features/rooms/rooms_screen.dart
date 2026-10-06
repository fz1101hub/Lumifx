import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';

/// Basic control of rooms and zones: on/off and brightness.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms & zones')),
      body: ListenableBuilder(
        listenable: bridge,
        builder: (context, _) {
          final home = bridge.home;
          final client = bridge.client;
          if (home == null || client == null) {
            return const Center(child: Text('No bridge connected.'));
          }
          return RefreshIndicator(
            onRefresh: bridge.refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (home.rooms.isNotEmpty) const _Header('Rooms'),
                for (final room in home.rooms)
                  _GroupTile(
                    key: ValueKey(room.id),
                    group: room,
                    home: home,
                    client: client,
                    onChanged: bridge.refresh,
                  ),
                if (home.zones.isNotEmpty) const _Header('Zones'),
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

  Future<void> _send(HueLightCommand command) async {
    final id = widget.group.groupedLightId;
    if (id == null) {
      return;
    }
    try {
      await widget.client.setGroupedLight(id, command);
      await widget.onChanged();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update ${widget.group.name}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.group.lightIds.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(widget.group.name),
              subtitle: Text('$count ${count == 1 ? 'light' : 'lights'}'),
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
                onChanged:
                    _on ? (value) => setState(() => _brightness = value) : null,
                onChangeEnd: (value) =>
                    _send(HueLightCommand(brightness: value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
