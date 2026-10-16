import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../automations/automations_screen.dart';
import '../bedtime/bedtime_screen.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_list_screen.dart';
import '../effects/effect_palette.dart';
import '../effects/player_route.dart';
import '../playlists/playlists_screen.dart';
import '../rooms/rooms_screen.dart';
import '../search/effect_search.dart';
import '../settings/settings_screen.dart';
import 'seasons.dart';
import 'wall_panel_screen.dart';

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
          if (context.isWide)
            IconButton(
              tooltip: l10n.wallPanel,
              icon: const Icon(Icons.tablet_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => const WallPanelScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.searchEffects,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const EffectSearchScreen()),
            ),
          ),
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
          padding: context.pageInsets(maxWidth: 1000),
          children: [
            _BridgeBanner(controller: bridge),
            if (seasonOf(AppScope.of(context).clock()) case final season?)
              _EffectShelf(
                title: switch (season) {
                  Season.halloween => l10n.seasonHalloween,
                  Season.christmas => l10n.seasonChristmas,
                },
                effectIds: [for (final e in effectsOfSeason(season)) e.id],
              ),
            _EffectShelf(
              title: l10n.favorites,
              effectIds: preferences.favorites,
            ),
            _EffectShelf(
              title: l10n.recentlyPlayed,
              effectIds: preferences.recents,
            ),
            const SizedBox(height: 12),
            _Sections(
              wide: context.isWide,
              children: [
                _SectionCard(
                  title: l10n.scenes,
                  subtitle: l10n.scenesSubtitle,
                  icon: Icons.gradient,
                  kind: EffectKind.scene,
                ),
                _SectionCard(
                  title: l10n.stories,
                  subtitle: l10n.storiesSubtitle,
                  icon: Icons.auto_awesome,
                  kind: EffectKind.story,
                ),
                _SectionCard(
                  title: l10n.interactive,
                  subtitle: l10n.interactiveSubtitle,
                  icon: Icons.graphic_eq,
                  kind: EffectKind.interactive,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                minVerticalPadding: 20,
                leading: const Icon(Icons.queue_music),
                title: Text(l10n.playlists),
                subtitle: Text(l10n.playlistsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PlaylistsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                minVerticalPadding: 20,
                leading: const Icon(Icons.bedtime_outlined),
                title: Text(l10n.bedtime),
                subtitle: Text(l10n.bedtimeSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const BedtimeScreen()),
                ),
              ),
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
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  minVerticalPadding: 20,
                  leading: const Icon(Icons.alarm),
                  title: Text(l10n.routines),
                  subtitle: Text(l10n.routinesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AutomationsScreen()),
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

/// The three experience cards: stacked on a phone, side by side on a
/// tablet, where each card is as tall as the tallest.
class _Sections extends StatelessWidget {
  const _Sections({required this.wide, required this.children});

  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            child,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ],
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
        if (AppScope.of(context).library.byId(id) case final effect?) effect,
    ];
    if (effects.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = context.l10n;
    // Larger tiles on a tablet, where there is room for them.
    final tileWidth = context.isWide ? 180.0 : 140.0;
    final tileHeight = context.isWide ? 120.0 : 96.0;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            // Grows with the user's font size so names still fit.
            height: MediaQuery.textScalerOf(context).scale(tileHeight),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: effects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final effect = effects[index];
                final colors = effectPalette(effect);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openPlayer(context, effect),
                  child: Ink(
                    width: tileWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            colors.length > 1 ? colors : [...colors, ...colors],
                      ),
                    ),
                    // A dark fade under the name keeps it readable on pale
                    // colours (yellow, white) too.
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
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EffectListScreen(kind: kind, title: title),
          ),
        );
    if (context.isWide) {
      // A tile: icon on top, text below, filling the card's height.
      final theme = Theme.of(context);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        minVerticalPadding: 20,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}
