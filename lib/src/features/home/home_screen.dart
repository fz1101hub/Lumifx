import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../effects/effect_list_screen.dart';
import '../rooms/rooms_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LumiFX'),
      ),
      body: ListenableBuilder(
        listenable: bridge,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BridgeBanner(controller: bridge),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Scenes',
              subtitle: 'Continuous atmospheres for everyday lighting.',
              icon: Icons.gradient,
              kind: EffectKind.scene,
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Stories',
              subtitle:
                  'Narrative effects with movement, surprises and timed events.',
              icon: Icons.auto_awesome,
              kind: EffectKind.story,
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Interactive',
              subtitle: 'Lighting that can react to audio and user input.',
              icon: Icons.graphic_eq,
              kind: EffectKind.interactive,
            ),
            if (bridge.isConnected) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  minVerticalPadding: 20,
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: const Text('Rooms & zones'),
                  subtitle:
                      const Text('Turn lights on and off, set brightness.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RoomsScreen()),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BridgeBanner extends StatelessWidget {
  const _BridgeBanner({required this.controller});

  final BridgeController controller;

  void _openSetup(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BridgeSetupScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (controller.status) {
      case BridgeStatus.initializing:
        return const LinearProgressIndicator();
      case BridgeStatus.unpaired:
      case BridgeStatus.pairing:
        return Card(
          color: colors.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Connect your Hue Bridge'),
            subtitle: const Text('Effects play as a preview until then.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSetup(context),
          ),
        );
      case BridgeStatus.unreachable:
        return Card(
          color: colors.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.wifi_off),
            title: const Text('Bridge not reachable'),
            subtitle: Text(controller.error ?? ''),
            trailing: IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh),
              onPressed: controller.refresh,
            ),
            onLongPress: () => _openSetup(context),
          ),
        );
      case BridgeStatus.connected:
        final home = controller.home;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
                controller.credentials?.bridge.displayName ?? 'Hue Bridge'),
            subtitle: Text(
              '${home?.lights.length ?? 0} lights · '
              '${home?.rooms.length ?? 0} rooms · '
              '${home?.zones.length ?? 0} zones',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'refresh') {
                  controller.refresh();
                } else if (value == 'forget') {
                  controller.forget();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                PopupMenuItem(value: 'forget', child: Text('Forget bridge')),
              ],
            ),
          ),
        );
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final EffectKind kind;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 20,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EffectListScreen(kind: kind, title: title),
          ),
        ),
      ),
    );
  }
}
