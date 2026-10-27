import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../automations/automations_screen.dart';
import '../bedtime/bedtime_screen.dart';
import '../bedtime/monster_spray_screen.dart';
import '../bedtime/moon_screen.dart';
import '../bedtime/nap_light_screen.dart';
import '../bedtime/tooth_fairy_screen.dart';
import '../timers/interval_training_screen.dart';
import '../timers/light_clock_screen.dart';
import '../calm/feelings_screen.dart';
import '../bedtime/ritual_screen.dart';
import '../cinema/cinema_screen.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_list_screen.dart';
import '../effects/effect_palette.dart';
import '../effects/player_route.dart';
import '../playlists/playlists_screen.dart';
import '../calm/breathing_screen.dart';
import '../fun/fun_screen.dart';
import '../house/house_screen.dart';
import '../kids/kids_mode.dart';
import '../links/nfc_stickers_screen.dart';
import '../notifications/notification_lights_screen.dart';
import '../music_box/music_box_screen.dart';
import '../rooms/rooms_screen.dart';
import '../routines/kid_routine.dart';
import '../routines/routines_screen.dart';
import '../routines/weekly_report_screen.dart';
import '../search/effect_search.dart';
import '../settings/settings_screen.dart';
import '../tales/tale_maker_screen.dart';
import '../timers/timers_screen.dart';
import '../weather/weather_screen.dart';
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
            if (_nowEntry(l10n, AppScope.of(context).clock()) case final now?)
              _NowCard(entry: now),
            if (festivalOf(AppScope.of(context).clock()) case final festival?)
              _EffectShelf(
                title: switch (festival) {
                  Festival.diwali => l10n.festivalDiwali,
                  Festival.hanukkah => l10n.festivalHanukkah,
                  Festival.lunarNewYear => l10n.festivalLunarNewYear,
                },
                effectIds: [for (final e in effectsOfFestival(festival)) e.id],
              ),
            if (seasonOf(AppScope.of(context).clock()) case final season?)
              _EffectShelf(
                title: switch (season) {
                  Season.newYear => l10n.seasonNewYear,
                  Season.valentine => l10n.seasonValentine,
                  Season.carnival => l10n.seasonCarnival,
                  Season.easter => l10n.seasonEaster,
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
            const SizedBox(height: 24),
            _HomeGroup(
              title: l10n.homeFamily,
              entries: [
                _HomeEntry(Icons.nights_stay_outlined, l10n.ritual,
                    l10n.ritualSubtitle, () => const BedtimeRitualScreen()),
                _HomeEntry(Icons.bedtime_outlined, l10n.bedtime,
                    l10n.bedtimeSubtitle, () => const BedtimeScreen()),
                _HomeEntry(Icons.wb_twilight, l10n.napLight,
                    l10n.napLightSubtitle, () => const NapLightScreen()),
                _HomeEntry(Icons.nightlight_round, l10n.moon, l10n.moonSubtitle,
                    () => const MoonScreen()),
                _HomeEntry(Icons.auto_awesome, l10n.toothFairy,
                    l10n.toothFairySubtitle, () => const ToothFairyScreen()),
                _HomeEntry(
                    Icons.sanitizer_outlined,
                    l10n.monsterSpray,
                    l10n.monsterSpraySubtitle,
                    () => const MonsterSprayScreen()),
                _HomeEntry(
                    Icons.music_note_outlined,
                    l10n.lullabies,
                    l10n.lullabiesSubtitle,
                    () => const MusicBoxScreen(festive: false)),
                _HomeEntry(Icons.auto_stories_outlined, l10n.storyMaker,
                    l10n.storyMakerSubtitle, () => const TaleMakerScreen()),
                _HomeEntry(Icons.spa_outlined, l10n.breathe,
                    l10n.breatheSubtitle, () => const BreathingScreen()),
                _HomeEntry(Icons.mood, l10n.feelings, l10n.feelingsSubtitle,
                    () => const FeelingsScreen()),
                _HomeEntry(Icons.timer_outlined, l10n.timers,
                    l10n.timersSubtitle, () => const TimersScreen()),
                _HomeEntry(Icons.traffic_outlined, l10n.lightClock,
                    l10n.lightClockSubtitle, () => const LightClockScreen()),
                _HomeEntry(Icons.checklist, l10n.kidRoutines,
                    l10n.kidRoutinesSubtitle, () => const RoutinesScreen()),
                _HomeEntry(
                    Icons.insights_outlined,
                    l10n.weeklyReport,
                    l10n.weeklyReportSubtitle,
                    () => const WeeklyReportScreen()),
                _HomeEntry(Icons.celebration_outlined, l10n.fun,
                    l10n.funSubtitle, () => const FunScreen()),
                _HomeEntry(Icons.child_care, l10n.kidsMode,
                    l10n.kidsModeSubtitle, () => const KidsSetupScreen()),
              ],
            ),
            _HomeGroup(
              title: l10n.homeMore,
              entries: [
                _HomeEntry(Icons.queue_music, l10n.playlists,
                    l10n.playlistsSubtitle, () => const PlaylistsScreen()),
                _HomeEntry(Icons.wb_sunny_outlined, l10n.weather,
                    l10n.weatherSubtitle, () => const WeatherScreen()),
                _HomeEntry(
                    Icons.fitness_center,
                    l10n.intervals,
                    l10n.intervalsSubtitle,
                    () => const IntervalTrainingScreen()),
                _HomeEntry(Icons.movie_outlined, l10n.cinema,
                    l10n.cinemaSubtitle, () => const CinemaScreen()),
                _HomeEntry(Icons.nfc, l10n.nfcStickers,
                    l10n.nfcStickersSubtitle, () => const NfcStickersScreen()),
              ],
            ),
            if (bridge.isConnected)
              _HomeGroup(
                title: l10n.homeYourHome,
                entries: [
                  _HomeEntry(Icons.meeting_room_outlined, l10n.roomsAndZones,
                      l10n.roomsAndZonesSubtitle, () => const RoomsScreen()),
                  _HomeEntry(Icons.alarm, l10n.routines, l10n.routinesSubtitle,
                      () => const AutomationsScreen()),
                  _HomeEntry(Icons.house_outlined, l10n.house,
                      l10n.houseSubtitle, () => const HouseScreen()),
                  if (AppScope.of(context).notificationLights.isSupported)
                    _HomeEntry(
                        Icons.notifications_active_outlined,
                        l10n.notificationLights,
                        l10n.notificationLightsSubtitle,
                        () => const NotificationLightsScreen()),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One place to go from the home: an icon, a title, a line about it.
/// What fits the time of day: the morning routine from 6 to 10, the
/// bedtime ritual from half past six to ten in the evening.
_HomeEntry? _nowEntry(AppLocalizations l10n, DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes >= 6 * 60 && minutes < 10 * 60) {
    return _HomeEntry(
      Icons.wb_sunny_outlined,
      KidRoutine.morning.title(l10n),
      l10n.nowMorning,
      () => const RoutineScreen(routine: KidRoutine.morning),
    );
  }
  if (minutes >= 18 * 60 + 30 && minutes < 22 * 60) {
    return _HomeEntry(
      Icons.nights_stay_outlined,
      l10n.ritual,
      l10n.nowEvening,
      () => const BedtimeRitualScreen(),
    );
  }
  return null;
}

/// The one thing suggested for now, at the top of the home.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.entry});

  final _HomeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primaryContainer,
        child: ListTile(
          minVerticalPadding: 14,
          leading:
              Icon(entry.icon, color: theme.colorScheme.onPrimaryContainer),
          title: Text(entry.title),
          subtitle: Text(entry.subtitle),
          textColor: theme.colorScheme.onPrimaryContainer,
          trailing: Icon(Icons.arrow_forward,
              color: theme.colorScheme.onPrimaryContainer),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => entry.screen()),
          ),
        ),
      ),
    );
  }
}

class _HomeEntry {
  const _HomeEntry(this.icon, this.title, this.subtitle, this.screen);

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() screen;
}

/// A titled group of [entries] in one card, so the home stays short.
class _HomeGroup extends StatelessWidget {
  const _HomeGroup({required this.title, required this.entries});

  final String title;
  final List<_HomeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, entry) in entries.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  ListTile(
                    minVerticalPadding: 14,
                    leading: Icon(entry.icon),
                    title: Text(entry.title),
                    subtitle: Text(entry.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => entry.screen()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
