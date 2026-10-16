import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/sound/soundscape.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../entertainment/entertainment_area_editor.dart';
import '../library/scene_editor.dart';
import '../library/sharing.dart';
import '../library/story_editor.dart';
import '../music/music_sync_controller.dart';
import 'effect_palette.dart';
import 'light_color_ui.dart';
import 'night_light_screen.dart';
import 'playback_controller.dart';
import 'read_along.dart';

class EffectPlayerScreen extends StatefulWidget {
  const EffectPlayerScreen({required this.effect, super.key});

  final LightingEffect effect;

  @override
  State<EffectPlayerScreen> createState() => _EffectPlayerScreenState();
}

/// The player of one effect. Playback itself belongs to the app (see
/// `AppScope.playback`), so leaving this screen never stops the lights;
/// when another effect plays, Play here cross-fades to this one.
class _EffectPlayerScreenState extends State<EffectPlayerScreen> {
  PlaybackController get controller => AppScope.of(context).playback;

  /// Whether the app's playback is on this screen's effect (or on the
  /// playlist this effect belongs to, which this screen then follows).
  bool _isCurrent(PlaybackController c) => c.isShownBy(widget.effect.id);

  /// The effect to show: this screen's, or the playlist's current one.
  LightingEffect _shown(PlaybackController c) => c.playlist != null &&
          _isCurrent(c)
      ? c.effect
      // Looked up again, so an edited scene of the user's shows its edit.
      : AppScope.of(context).library.byId(widget.effect.id) ?? widget.effect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = controller;
    if (c.status == PlaybackStatus.idle && !_isCurrent(c)) {
      // Nothing plays: this effect becomes the one Play starts. After the
      // frame, since listeners of the playback cannot rebuild mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && c.status == PlaybackStatus.idle) {
          unawaited(c.switchEffect(widget.effect));
        }
      });
    }
  }

  Future<void> _createArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const EntertainmentAreaEditor()),
    );
  }

  static const _sleepOptions = [15, 30, 45, 60, 90];

  Future<void> _chooseSleepTimer() async {
    final l10n = context.l10n;
    final current = controller.sleepTimer?.inMinutes ?? 0;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.sleepTimer),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.sleepTimerDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final option in [0, ..._sleepOptions])
            ListTile(
              leading: Icon(option == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(option == 0
                  ? l10n.sleepTimerOff
                  : l10n.sleepTimerMinutes(option)),
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
    if (minutes != null) {
      controller
          .setSleepTimer(minutes == 0 ? null : Duration(minutes: minutes));
    }
  }

  String _sleepLabel(AppLocalizations l10n, PlaybackController c) {
    if (c.isFadingOut) {
      return l10n.sleepTimerFading;
    }
    final remaining = c.sleepRemaining;
    if (remaining != null) {
      // Round up, so "1 minute" is shown until the lights actually go out.
      return l10n.sleepTimerRemaining((remaining.inSeconds / 60).ceil());
    }
    final timer = c.sleepTimer;
    return timer == null
        ? l10n.sleepTimer
        : l10n.sleepTimerMinutes(timer.inMinutes);
  }

  /// The dropdown entry that opens the several-rooms picker.
  static const _severalRooms = '__several__';

  Future<void> _chooseSeveralRooms() async {
    final c = controller;
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (_) => _SeveralRoomsDialog(
        groups: c.groups,
        selected: {for (final g in c.roomGroups) g.id},
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) {
      // Rebuild so the dropdown shows the target again.
      setState(() {});
      return;
    }
    await c.changeTarget(chosen.length == 1
        ? 'group:${chosen.single}'
        : PlaybackController.severalRoomsKey(chosen));
  }

  /// Asks for a name and saves the lights' current colours as a Hue
  /// scene in the room or zone.
  Future<void> _saveAsHueScene(LightingEffect effect) async {
    final l10n = context.l10n;
    final c = controller;
    final room = c.group?.name ?? '';
    final answer = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => _SceneNameDialog(
        initial: l10n.effectName(effect),
        canMove: c.dynamicPalette != null,
      ),
    );
    if (answer == null || answer.$1.trim().isEmpty || !mounted) {
      return;
    }
    final (name, dynamic) = answer;
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final scene = await c.saveAsHueScene(name, dynamic: dynamic);
      message = scene == null
          ? l10n.sceneNotSaved
          : l10n.sceneSaved(scene.name, room);
    } on Object catch (error) {
      message = l10n.couldNotSaveScene(describeError(l10n, error));
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Play/pause, with a one-time warning before the first effect that
  /// flashes. Nothing plays until the user has chosen.
  Future<void> _toggle() async {
    final c = controller;
    final current = _isCurrent(c);
    if ((!current || c.status == PlaybackStatus.idle) &&
        widget.effect.hasRapidFlashes &&
        !await confirmFlashingLights(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (!current) {
      await c.switchEffect(widget.effect);
      if (c.status == PlaybackStatus.idle) {
        await c.start();
      } else if (c.status == PlaybackStatus.paused) {
        await c.resume();
      }
      return;
    }
    await c.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildFor(context, _shown(controller)),
    );
  }

  Widget _buildFor(BuildContext context, LightingEffect effect) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final description = l10n.effectDescription(effect);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.effectName(effect)),
        actions: [
          if (AppScope.of(context).library.userScene(effect.id)
              case final scene?) ...[
            IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () =>
                  showShareDialog(context, SharedBundle(scenes: [scene])),
            ),
            IconButton(
              tooltip: l10n.editScene,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SceneEditor(scene: scene),
                ),
              ),
            ),
          ],
          if (AppScope.of(context).library.userStory(effect.id)
              case final story?) ...[
            IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () =>
                  showShareDialog(context, SharedBundle(stories: [story])),
            ),
            IconButton(
              tooltip: l10n.editStory,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoryEditor(story: story),
                ),
              ),
            ),
          ],
          IconButton(
            tooltip: l10n.nightLight,
            icon: const Icon(Icons.nightlight_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => NightLightScreen(effect: effect),
              ),
            ),
          ),
          _FavoriteButton(effectId: effect.id),
        ],
      ),
      body: Builder(
        builder: (context) {
          final c = controller;
          final busy = c.isBusy;
          final current = _isCurrent(c);
          final preferences = AppScope.of(context).preferences;
          final narration =
              narrationOf(effect, l10n, AppScope.of(context).library);
          final variantId = preferences.variantOf(effect.id);
          void setVariant(String? id) => current
              ? c.setVariant(id)
              : preferences.setVariant(effect.id, id);
          final playing = current && c.isPlaying;
          final active = current &&
              (c.status == PlaybackStatus.playing ||
                  c.status == PlaybackStatus.paused);
          final other = !current && c.status != PlaybackStatus.idle;
          final playlist = current ? c.playlist : null;
          final groups = c.groups;
          final areas = c.areas;
          final targetKeys = [
            for (final area in areas) 'area:${area.id}',
            for (final group in groups) 'group:${group.id}',
          ];
          final controls = c.controls;
          // What to play and where (setup) and the lamps with the
          // transport and sliders (stage): one column on a phone, two
          // panes side by side on a tablet.
          final setup = <Widget>[
            if (description.isNotEmpty)
              Text(description, style: theme.textTheme.bodyLarge),
            if (effect.variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _VariantChip(
                    label: l10n.variantClassic,
                    colors: effectPalette(effect),
                    selected: variantId == null,
                    onSelected: () => setVariant(null),
                  ),
                  for (final variant in effect.variants)
                    _VariantChip(
                      label: l10n.variantName(variant),
                      colors: [
                        for (final hex in variant.palette)
                          LightColor.fromHex(hex).toColor(),
                      ],
                      selected: variantId == variant.id,
                      onSelected: () => setVariant(variant.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              // Rebuilt when the available targets change, so the field
              // never holds a value that is no longer in the list.
              key: ValueKey(Object.hashAll([...targetKeys, c.selectedTarget])),
              initialValue: c.selectedTarget,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.playOn,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.previewOnly)),
                for (final area in areas)
                  DropdownMenuItem(
                    value: 'area:${area.id}',
                    child: _TargetLabel(
                      icon: Icons.bolt,
                      text: l10n.targetStreaming(area.name),
                    ),
                  ),
                for (final group in groups)
                  DropdownMenuItem(
                    value: 'group:${group.id}',
                    child: _TargetLabel(
                      icon: Icons.meeting_room_outlined,
                      text: l10n.targetGroup(group.name, group.lightIds.length),
                    ),
                  ),
                if (c.playsSeveralRooms)
                  DropdownMenuItem(
                    value: c.selectedTarget,
                    child: _TargetLabel(
                      icon: Icons.house_outlined,
                      text: c.targetName!,
                    ),
                  ),
                if (groups.length > 1)
                  DropdownMenuItem(
                    value: _severalRooms,
                    child: _TargetLabel(
                      icon: Icons.add_home_outlined,
                      text: l10n.severalRooms,
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) => value == _severalRooms
                      ? _chooseSeveralRooms()
                      : c.changeTarget(value),
            ),
            if (c.playsSeveralRooms) ...[
              const SizedBox(height: 8),
              Text(l10n.severalRoomsHint, style: theme.textTheme.bodySmall),
            ],
            if (c.bridgeUnreachable) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerBridgeUnreachable,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (c.streamingUnavailable) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerStreamingUnavailable,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (effect.prefersStreaming && c.group != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerPrefersStreaming,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (c.groupLights.length > 1) ...[
              const SizedBox(height: 12),
              Text(l10n.lightsToPlay, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in c.groupLights)
                    FilterChip(
                      label: Text(entry.light.name),
                      selected: entry.enabled,
                      onSelected:
                          busy ? null : (_) => c.toggleLight(entry.light.id),
                    ),
                ],
              ),
            ],
            if (c.home != null && !c.streamingUnavailable && areas.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.playerCreateAreaHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _createArea,
                    child: Text(l10n.createArea),
                  ),
                ],
              ),
          ];
          final stage = <Widget>[
            if (other)
              _InfoCard(
                icon: Icons.graphic_eq,
                text: l10n.nowPlayingOther(l10n.effectName(c.effect)),
              ),
            if (playlist != null)
              _InfoCard(
                icon: Icons.queue_music,
                text: l10n.playlistProgress(
                  playlist.name,
                  c.playlistIndex + 1,
                  c.playlistEffects.length,
                ),
                action: IconButton(
                  tooltip: l10n.nextEffect,
                  icon: const Icon(Icons.skip_next),
                  onPressed: busy ? null : c.nextInPlaylist,
                ),
              ),
            if (other || playlist != null) const SizedBox(height: 16),
            _LampPreview(
              player: current ? c.player : null,
              names: [
                for (final slot in c.lightNames) describeSlot(l10n, slot),
              ],
            ),
            if (narration.isNotEmpty && preferences.readAlong) ...[
              const SizedBox(height: 16),
              ReadAlongCaption(
                effect: effect,
                lines: narration,
                player: current ? c.player : null,
              ),
            ],
            if (effect.usesMicrophone) ...[
              const SizedBox(height: 16),
              _MusicMeter(
                player: current ? c.player : null,
                music: current ? c.music : null,
                source: c.musicSource,
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : _toggle,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                    label: Text(busy
                        ? l10n.connecting
                        : playing
                            ? l10n.pause
                            : l10n.play),
                  ),
                  if (active)
                    OutlinedButton.icon(
                      onPressed: c.stop,
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.stop),
                    ),
                  if (active && c.canSaveAsHueScene)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _saveAsHueScene(effect),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(l10n.saveAsHueScene),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy || c.isFadingOut ? null : _chooseSleepTimer,
                    icon: Icon(c.sleepTimer == null
                        ? Icons.bedtime_outlined
                        : Icons.bedtime),
                    label: Text(_sleepLabel(l10n, c)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ControlSlider(
              label: l10n.brightness,
              value: controls.brightness,
              onChanged: (v) => c.setControls(controls.copyWith(brightness: v)),
            ),
            _ControlSlider(
              label: l10n.intensity,
              value: controls.intensity,
              onChanged: (v) => c.setControls(controls.copyWith(intensity: v)),
            ),
            if (effect.usesMicrophone)
              _ControlSlider(
                label: l10n.sensitivity,
                value: c.sensitivity,
                min: 0.5,
                max: 2.5,
                onChanged: c.setSensitivity,
              )
            else
              _ControlSlider(
                label: l10n.speed,
                value: controls.speed,
                min: 0.25,
                max: 3,
                onChanged: (v) => c.setControls(controls.copyWith(speed: v)),
              ),
            if (!soundscapeOf(effect).isSilent) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(preferences.soundOn
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined),
                title: Text(l10n.sound),
                subtitle: Text(l10n.soundDescription),
                value: preferences.soundOn,
                onChanged: preferences.setSoundOn,
              ),
              if (preferences.soundOn)
                _ControlSlider(
                  label: l10n.volume,
                  value: preferences.soundVolume,
                  onChanged: preferences.setSoundVolume,
                ),
            ],
            if (narration.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_stories_outlined),
                title: Text(l10n.readAlong),
                subtitle: Text(l10n.readAlongDescription),
                value: preferences.readAlong,
                onChanged: preferences.setReadAlong,
              ),
          ];
          if (context.isWide) {
            return ListView(
              padding: context.pageInsets(maxWidth: 1100),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: setup,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SizedBox(height: 8), ...stage],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [...setup, const SizedBox(height: 24), ...stage],
          );
        },
      ),
    );
  }
}

/// Ticks for the rooms and zones that should play together.
class _SeveralRoomsDialog extends StatefulWidget {
  const _SeveralRoomsDialog({required this.groups, required this.selected});

  final List<HueGroup> groups;
  final Set<String> selected;

  @override
  State<_SeveralRoomsDialog> createState() => _SeveralRoomsDialogState();
}

class _SeveralRoomsDialogState extends State<_SeveralRoomsDialog> {
  late final Set<String> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.severalRooms),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final group in widget.groups)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(group.name),
              subtitle: Text(l10n.lightCount(group.lightIds.length)),
              value: _chosen.contains(group.id),
              onChanged: (on) => setState(() {
                on ?? false ? _chosen.add(group.id) : _chosen.remove(group.id);
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                    for (final g in widget.groups)
                      if (_chosen.contains(g.id)) g.id,
                  ]),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

/// Asks for the name of a new Hue scene (the bridge keeps at most 32
/// characters).
class _SceneNameDialog extends StatefulWidget {
  const _SceneNameDialog({required this.initial, required this.canMove});

  final String initial;

  /// The effect can be saved as a scene that keeps moving.
  final bool canMove;

  @override
  State<_SceneNameDialog> createState() => _SceneNameDialogState();
}

class _SceneNameDialogState extends State<_SceneNameDialog> {
  late final _name = TextEditingController(
    text: widget.initial.length > HueBridgeClient.maxSceneNameLength
        ? widget.initial.substring(0, HueBridgeClient.maxSceneNameLength)
        : widget.initial,
  );

  late bool _moving = widget.canMove;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.saveAsHueScene),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.saveAsHueSceneDescription),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: HueBridgeClient.maxSceneNameLength,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop((value, _moving)),
          ),
          if (widget.canMove)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sceneKeepsMoving),
              subtitle: Text(l10n.sceneKeepsMovingDescription),
              value: _moving,
              onChanged: (value) => setState(() => _moving = value),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_name.text, _moving)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// A short note above the lamps (what else plays, the playlist).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            if (action case final action?)
              action
            else
              const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// A colour variant: a swatch of its palette and its name.
class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: colors.length > 1
                ? [...colors, colors.first]
                : [...colors, ...colors],
          ),
        ),
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// The one-time warning before the first effect with lightning or beats.
/// Returns false when the user has not answered (nothing should play);
/// true at once when the warning was already shown.
Future<bool> confirmFlashingLights(BuildContext context) async {
  final preferences = AppScope.of(context).preferences;
  if (preferences.flashWarningShown) {
    return true;
  }
  final soften = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FlashWarningDialog(),
  );
  if (soften == null) {
    return false;
  }
  unawaited(preferences.setFlashWarningShown(true));
  if (soften) {
    unawaited(preferences.setSoftFlashes(true));
  }
  return true;
}

/// Shown once before the first effect with lightning or beats.
class _FlashWarningDialog extends StatelessWidget {
  const _FlashWarningDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.flash_on_outlined),
      title: Text(l10n.photosensitivityTitle),
      content: Text(l10n.photosensitivityBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.softenFlashes),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.continueAction),
        ),
      ],
    );
  }
}

/// Live bass / mid / treble levels, a beat light and the tempo.
class _MusicMeter extends StatelessWidget {
  const _MusicMeter({
    required this.player,
    required this.music,
    required this.source,
  });

  final EffectPlayer? player;
  final MusicSyncController? music;
  final MusicSource source;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final music = this.music;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final phoneAudio = source == MusicSource.phoneAudio;
    if (player == null || music == null || !music.isListening) {
      return Row(
        children: [
          Icon(phoneAudio ? Icons.phone_android : Icons.mic_none, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phoneAudio ? l10n.musicSyncHintPhoneAudio : l10n.musicSyncHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }
    // Repaint with the player's frames, which already run at tick rate.
    return StreamBuilder<List<LightFrame>>(
      stream: player.frames,
      builder: (context, _) {
        final f = music.features;
        final onBeat = f.secondsSinceBeat < 0.12;
        return Row(
          children: [
            Icon(
              phoneAudio ? Icons.phone_android : Icons.mic,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            for (final (label, value) in [
              (l10n.bass, f.bass),
              (l10n.mid, f.mid),
              (l10n.treble, f.treble),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: value,
                        semanticsLabel: label,
                        semanticsValue: '${(value * 100).round()}%',
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onBeat
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                f.bpm == null ? l10n.listening : l10n.bpm(f.bpm!.round()),
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.effectId});

  final String effectId;

  @override
  Widget build(BuildContext context) {
    final preferences = AppScope.of(context).preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final favorite = preferences.isFavorite(effectId);
        final l10n = context.l10n;
        return IconButton(
          tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          icon: Icon(favorite ? Icons.star : Icons.star_border),
          onPressed: () => preferences.toggleFavorite(effectId),
        );
      },
    );
  }
}

class _TargetLabel extends StatelessWidget {
  const _TargetLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _LampPreview extends StatelessWidget {
  const _LampPreview({required this.player, required this.names});

  final EffectPlayer? player;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (player == null) {
      return _lamps(context, List.filled(names.length, LightFrame.off));
    }
    return StreamBuilder<List<LightFrame>>(
      stream: player.frames,
      initialData: player.currentFrames,
      builder: (context, snapshot) {
        final frames = snapshot.data ?? const <LightFrame>[];
        return _lamps(
          context,
          frames.length == names.length
              ? frames
              : List.filled(names.length, LightFrame.off),
        );
      },
    );
  }

  Widget _lamps(BuildContext context, List<LightFrame> frames) {
    // One description for screen readers instead of a circle per lamp,
    // which would change many times a second.
    return Semantics(
      container: true,
      label: context.l10n.lampPreview(frames.length, names.join(', ')),
      excludeSemantics: true,
      child: _lampWrap(context, frames),
    );
  }

  Widget _lampWrap(BuildContext context, List<LightFrame> frames) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (var i = 0; i < frames.length; i++)
          SizedBox(
            width: 64,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: frames[i].toDisplayColor(),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: frames[i]
                            .color
                            .toColor()
                            .withValues(alpha: frames[i].brightness * 0.8),
                        blurRadius: 24 * frames[i].brightness,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  names[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ControlSlider extends StatelessWidget {
  const _ControlSlider({
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
    return Row(
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
    );
  }
}
