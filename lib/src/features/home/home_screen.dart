import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../common/app_text.dart';
import '../effects/catalog/effect_catalog.dart';
import '../effects/effect_list_screen.dart';
import '../effects/effect_palette.dart';
import '../effects/effect_player_screen.dart';
import '../rooms/rooms_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final bridge = scope.bridge;
    final preferences = scope.preferences;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([bridge, preferences]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BridgeBanner(controller: bridge),
            _EffectShelf(
              title: l10n.favorites,
              effectIds: preferences.favorites,
            ),
            _EffectShelf(
              title: l10n.recentlyPlayed,
              effectIds: preferences.recents,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.scenes,
              subtitle: l10n.scenesSubtitle,
              icon: Icons.gradient,
              kind: EffectKind.scene,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.stories,
              subtitle: l10n.storiesSubtitle,
              icon: Icons.auto_awesome,
              kind: EffectKind.story,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.interactive,
              subtitle: l10n.interactiveSubtitle,
              icon: Icons.graphic_eq,
              kind: EffectKind.interactive,
            ),
            if (bridge.isConnected) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  minVerticalPadding: 20,
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text(l10n.roomsAndZones),
                  subtitle: Text(l10n.roomsAndZonesSubtitle),
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

/// A horizontal row of effects; hidden when empty.
class _EffectShelf extends StatelessWidget {
  const _EffectShelf({required this.title, required this.effectIds});

  final String title;
  final List<String> effectIds;

  @override
  Widget build(BuildContext context) {
    final effects = [
      for (final id in effectIds)
        if (effectById(id) case final effect?) effect,
    ];
    if (effects.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            // Grows with the user's font size so names still fit.
            height: MediaQuery.textScalerOf(context).scale(96),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: effects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final effect = effects[index];
                final colors = effectPalette(effect);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EffectPlayerScreen(effect: effect),
                    ),
                  ),
                  child: Ink(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            colors.length > 1 ? colors : [...colors, ...colors],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        l10n.effectName(effect),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
    final l10n = context.l10n;
    switch (controller.status) {
      case BridgeStatus.initializing:
        return const LinearProgressIndicator();
      case BridgeStatus.unpaired:
      case BridgeStatus.pairing:
        return Card(
          color: colors.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(l10n.connectYourBridge),
            subtitle: Text(l10n.connectYourBridgeSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSetup(context),
          ),
        );
      case BridgeStatus.unreachable:
        final problem = controller.problem;
        return Card(
          color: colors.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.wifi_off),
            title: Text(l10n.bridgeNotReachable),
            subtitle: Text(
              problem == null ? '' : describeBridgeProblem(l10n, problem),
            ),
            trailing: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh),
              onPressed: controller.refresh,
            ),
            // Tapping the card offers to set the bridge up again.
            onTap: () => _openSetup(context),
          ),
        );
      case BridgeStatus.connected:
        final home = controller.home;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
                controller.credentials?.bridge.displayName ?? l10n.hueBridge),
            subtitle: Text([
              l10n.lightCount(home?.lights.length ?? 0),
              l10n.roomCount(home?.rooms.length ?? 0),
              l10n.zoneCount(home?.zones.length ?? 0),
            ].join(' · ')),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'refresh') {
                  controller.refresh();
                } else if (value == 'forget') {
                  confirmForgetBridge(context, controller);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'refresh', child: Text(l10n.refresh)),
                PopupMenuItem(value: 'forget', child: Text(l10n.forgetBridge)),
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
