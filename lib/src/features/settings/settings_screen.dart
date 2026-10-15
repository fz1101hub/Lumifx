import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../common/app_text.dart';
import '../entertainment/entertainment_areas_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final bridge = scope.bridge;
    final preferences = scope.preferences;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([bridge, preferences]),
        builder: (context, _) {
          final controls = preferences.defaultControls;
          void update(EffectControls value) =>
              preferences.setDefaultControls(value);

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _Header(l10n.hueBridge),
              ..._bridgeTiles(context, bridge),
              const Divider(height: 32),
              _Header(l10n.playbackDefaults),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.playbackDefaultsDescription,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _SliderTile(
                label: l10n.brightness,
                value: controls.brightness,
                onChanged: (v) => update(controls.copyWith(brightness: v)),
              ),
              _SliderTile(
                label: l10n.intensity,
                value: controls.intensity,
                onChanged: (v) => update(controls.copyWith(intensity: v)),
              ),
              _SliderTile(
                label: l10n.speed,
                value: controls.speed,
                min: 0.25,
                max: 3,
                onChanged: (v) => update(controls.copyWith(speed: v)),
              ),
              SwitchListTile(
                title: Text(l10n.restoreLights),
                subtitle: Text(l10n.restoreLightsDescription),
                value: preferences.restoreLights,
                onChanged: preferences.setRestoreLights,
              ),
              const Divider(height: 32),
              _Header(l10n.about),
              ListTile(
                title: Text(l10n.appTitle),
                subtitle: Text(l10n.aboutDescription),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bridgeTiles(BuildContext context, BridgeController bridge) {
    final l10n = context.l10n;
    final credentials = bridge.credentials;
    if (credentials == null) {
      return [
        ListTile(
          leading: const Icon(Icons.add_link),
          title: Text(l10n.connectABridge),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BridgeSetupScreen()),
          ),
        ),
      ];
    }
    final home = bridge.home;
    final problem = bridge.problem;
    final canStream = bridge.isConnected && credentials.clientKey != null;
    return [
      ListTile(
        leading: Icon(
          bridge.isConnected ? Icons.check_circle_outline : Icons.wifi_off,
        ),
        title: Text(credentials.bridge.displayName),
        subtitle: Text(
          bridge.isConnected
              ? '${credentials.bridge.host} · '
                  '${l10n.lightCount(home?.lights.length ?? 0)}'
              : problem == null
                  ? l10n.notReachable
                  : describeBridgeProblem(l10n, problem),
        ),
        trailing: IconButton(
          tooltip: l10n.refresh,
          icon: const Icon(Icons.refresh),
          onPressed: bridge.refresh,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bolt),
        title: Text(l10n.entertainmentStreaming),
        subtitle: Text(
          credentials.clientKey == null
              ? l10n.streamingNotAvailable
              : l10n.areaCount(home?.entertainmentAreas.length ?? 0),
        ),
        trailing: const Icon(Icons.chevron_right),
        enabled: canStream,
        onTap: canStream
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EntertainmentAreasScreen(),
                  ),
                )
            : null,
      ),
      ListTile(
        leading: const Icon(Icons.link_off),
        title: Text(l10n.forgetThisBridge),
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
