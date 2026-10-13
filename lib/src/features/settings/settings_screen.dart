import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../entertainment/entertainment_areas_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final bridge = scope.bridge;
    final preferences = scope.preferences;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([bridge, preferences]),
        builder: (context, _) {
          final controls = preferences.defaultControls;
          void update(EffectControls value) =>
              preferences.setDefaultControls(value);

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const _Header('Hue Bridge'),
              ..._bridgeTiles(context, bridge),
              const Divider(height: 32),
              const _Header('Playback defaults'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Every effect starts with these settings. You can still '
                  'change them while it plays.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _SliderTile(
                label: 'Brightness',
                value: controls.brightness,
                onChanged: (v) => update(controls.copyWith(brightness: v)),
              ),
              _SliderTile(
                label: 'Intensity',
                value: controls.intensity,
                onChanged: (v) => update(controls.copyWith(intensity: v)),
              ),
              _SliderTile(
                label: 'Speed',
                value: controls.speed,
                min: 0.25,
                max: 3,
                onChanged: (v) => update(controls.copyWith(speed: v)),
              ),
              SwitchListTile(
                title: const Text('Restore lights when an effect stops'),
                subtitle: const Text(
                  'Puts each light back to the colour and brightness it had '
                  'before the effect started.',
                ),
                value: preferences.restoreLights,
                onChanged: preferences.setRestoreLights,
              ),
              const Divider(height: 32),
              const _Header('About'),
              const ListTile(
                title: Text('LumiFX'),
                subtitle: Text(
                  'Original scenes and stories for Philips Hue. '
                  'Not affiliated with Signify or Philips.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bridgeTiles(BuildContext context, BridgeController bridge) {
    final credentials = bridge.credentials;
    if (credentials == null) {
      return [
        ListTile(
          leading: const Icon(Icons.add_link),
          title: const Text('Connect a Hue Bridge'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BridgeSetupScreen()),
          ),
        ),
      ];
    }
    final home = bridge.home;
    return [
      ListTile(
        leading: Icon(
          bridge.isConnected ? Icons.check_circle_outline : Icons.wifi_off,
        ),
        title: Text(credentials.bridge.displayName),
        subtitle: Text(
          bridge.isConnected
              ? '${credentials.bridge.host} · ${home?.lights.length ?? 0} lights'
              : bridge.error ?? 'Not reachable',
        ),
        trailing: IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: bridge.refresh,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bolt),
        title: const Text('Entertainment streaming'),
        subtitle: Text(
          credentials.clientKey == null
              ? 'Not available: forget the bridge and pair again.'
              : '${home?.entertainmentAreas.length ?? 0} entertainment areas',
        ),
        trailing: const Icon(Icons.chevron_right),
        enabled: bridge.isConnected && credentials.clientKey != null,
        onTap: bridge.isConnected && credentials.clientKey != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EntertainmentAreasScreen(),
                  ),
                )
            : null,
      ),
      ListTile(
        leading: const Icon(Icons.link_off),
        title: const Text('Forget this bridge'),
        onTap: () => confirmForgetBridge(context, bridge),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(88),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
