import 'package:flutter/material.dart';

import '../buttons/hue_buttons_screen.dart';
import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/speech/speaker.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/bridge_setup_screen.dart';
import '../bridge/forget_bridge_dialog.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../entertainment/entertainment_areas_screen.dart';
import '../library/sharing.dart';
import '../home/wall_panel_screen.dart';
import '../links/links_screen.dart';
import 'voice_screen.dart';

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
        listenable: Listenable.merge([bridge, preferences, scope.playback]),
        builder: (context, _) {
          final controls = preferences.defaultControls;
          void update(EffectControls value) =>
              preferences.setDefaultControls(value);

          return ListView(
            padding: context.pageInsets(horizontal: 0, top: 12, bottom: 12),
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
                title: Text(l10n.gentleStart),
                subtitle: Text(l10n.gentleStartDescription),
                value: preferences.gentleStart,
                onChanged: preferences.setGentleStart,
              ),
              SwitchListTile(
                title: Text(l10n.restoreLights),
                subtitle: Text(l10n.restoreLightsDescription),
                value: preferences.restoreLights,
                onChanged: preferences.setRestoreLights,
              ),
              SwitchListTile(
                title: Text(l10n.softFlashes),
                subtitle: Text(scope.playback.systemReducesMotion
                    ? l10n.softFlashesBySystem
                    : l10n.softFlashesDescription),
                value: scope.playback.softFlashes,
                onChanged: scope.playback.systemReducesMotion
                    ? null
                    : preferences.setSoftFlashes,
              ),
              if (scope.background.isSupported ||
                  scope.liveActivity.isSupported)
                SwitchListTile(
                  title: Text(l10n.keepPlayingScreenOff),
                  subtitle: Text(scope.background.isSupported
                      ? l10n.keepPlayingScreenOffDescription
                      : l10n.keepPlayingScreenOffIos),
                  value: preferences.keepPlayingScreenOff,
                  onChanged: preferences.setKeepPlayingScreenOff,
                ),
              const Divider(height: 32),
              _Header(l10n.readAloud),
              const _VoiceTile(),
              if (scope.phoneAudioInput != null) ...[
                const Divider(height: 32),
                _Header(l10n.musicSource),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.musicSourceDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                for (final (source, title, subtitle, icon) in [
                  (
                    MusicSource.microphone,
                    l10n.musicSourceMicrophone,
                    l10n.musicSourceMicrophoneDescription,
                    Icons.mic_none,
                  ),
                  (
                    MusicSource.phoneAudio,
                    l10n.musicSourcePhoneAudio,
                    l10n.musicSourcePhoneAudioDescription,
                    Icons.phone_android,
                  ),
                ])
                  ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Icon(preferences.musicSource == source
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                    selected: preferences.musicSource == source,
                    onTap: () => preferences.setMusicSource(source),
                  ),
              ],
              if (preferences.userScenes.isNotEmpty ||
                  preferences.userStories.isNotEmpty ||
                  preferences.playlists.isNotEmpty) ...[
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: Text(l10n.shareAll),
                  subtitle: Text(l10n.shareAllSubtitle),
                  onTap: () => showShareDialog(
                    context,
                    SharedBundle(
                      scenes: preferences.userScenes,
                      stories: preferences.userStories,
                      playlists: preferences.playlists,
                    ),
                  ),
                ),
              ],
              const Divider(height: 32),
              if (AppScope.of(context).bridge.isConnected)
                ListTile(
                  leading: const Icon(Icons.radio_button_checked),
                  title: Text(l10n.hueButtons),
                  subtitle: Text(l10n.hueButtonsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HueButtonsScreen(),
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.tablet_outlined),
                title: Text(l10n.wallPanel),
                subtitle: Text(l10n.wallPanelDescription),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => const WallPanelScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(l10n.linksTitle),
                subtitle: Text(l10n.linksSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LinksScreen()),
                ),
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
      if (bridge.otherBridges.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(l10n.otherBridges,
              style: Theme.of(context).textTheme.titleSmall),
        ),
      for (final other in bridge.otherBridges)
        ListTile(
          leading: const Icon(Icons.home_work_outlined),
          title: Text(other.bridge.displayName),
          subtitle: Text(other.bridge.host),
          trailing: TextButton(
            onPressed: () => switchBridge(context, bridge, other.bridge.id),
            child: Text(l10n.switchToBridge(other.bridge.displayName)),
          ),
        ),
      ListTile(
        leading: const Icon(Icons.add_home_work_outlined),
        title: Text(l10n.addAnotherBridge),
        subtitle: Text(l10n.addAnotherBridgeSubtitle),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BridgeSetupScreen()),
        ),
      ),
    ];
  }
}

/// The storyteller's voice: automatic (and which one that is) or the
/// voice chosen; opens [VoiceScreen].
class _VoiceTile extends StatefulWidget {
  const _VoiceTile();

  @override
  State<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<_VoiceTile> {
  Future<List<SpeechVoice>>? _voices;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    if (language != _language) {
      _language = language;
      _voices = AppScope.of(context).speaker.voices(language);
    }
  }

  Future<void> _open() async {
    final speaker = AppScope.of(context).speaker;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VoiceScreen()),
    );
    if (mounted) {
      // A voice may have been downloaded meanwhile.
      setState(() {
        _voices = speaker.voices(_language!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chosenId =
        AppScope.of(context).preferences.speechVoiceFor(_language!);
    return FutureBuilder<List<SpeechVoice>>(
      future: _voices,
      builder: (context, snapshot) {
        final voices = snapshot.data ?? const <SpeechVoice>[];
        final chosen = voices.where((v) => v.id == chosenId).firstOrNull;
        final best = bestVoice(voices);
        return ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: Text(l10n.storytellerVoice),
          subtitle: Text(switch ((chosen, best)) {
            (final chosen?, _) => chosen.name,
            (null, final best?) =>
              l10n.storytellerVoiceAutomaticNamed(best.name),
            (null, null) => l10n.storytellerVoiceAutomatic,
          }),
          trailing: const Icon(Icons.chevron_right),
          onTap: _open,
        );
      },
    );
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
              semanticFormatterCallback: (v) =>
                  '$label ${(100 * (v - min) / (max - min)).round()}%',
            ),
          ),
        ],
      ),
    );
  }
}
