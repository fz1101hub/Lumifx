import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/color/photo_palette.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/photos/photo_picker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import 'user_scene.dart';

/// Creates a scene of the user's own, or edits [scene]: a name, two to
/// five colours and how they move, with a live preview.
class SceneEditor extends StatefulWidget {
  const SceneEditor({this.scene, super.key});

  final UserScene? scene;

  /// The colours offered, from warm to cool, then whites.
  static const swatches = [
    '#FF2D2D', '#FF6A00', '#FF9A2E', '#FFC300', '#F9E04B', '#B5E550', //
    '#3DDC84', '#00C2A8', '#00B3FF', '#1A4BFF', '#5B2EFF', '#9B30FF',
    '#D23CFF', '#FF4FC3', '#FF6F91', '#FFB7C5', '#FFD7A8', '#FFE9C9',
    '#FFF4E5', '#FFFFFF', '#CFE8FF', '#8FD3FF', '#2E7BFF', '#0B2AA8',
  ];

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  late final _name = TextEditingController(text: widget.scene?.name ?? '');
  late List<String> _colors =
      widget.scene?.colors ?? const ['#FF6A00', '#FF2D2D', '#FFC300'];
  late SceneMotion _motion = widget.scene?.motion ?? SceneMotion.drift;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  UserScene get _draft => UserScene(
        id: widget.scene?.id ?? '${UserScene.idPrefix}draft',
        name: _name.text.trim(),
        colors: _colors,
        motion: _motion,
      );

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final scene = UserScene(
      id: widget.scene?.id ?? UserScene.newId(),
      name: _name.text.trim(),
      colors: _colors,
      motion: _motion,
    );
    await scope.preferences.saveUserScene(scene);
    // Playing it right now: show the edit on the lights at once.
    final playback = scope.playback;
    final edited = scope.library.byId(scene.id);
    if (edited != null &&
        playback.effect.id == scene.id &&
        playback.status != PlaybackStatus.idle) {
      await playback.switchEffect(edited);
    }
    if (mounted) {
      Navigator.of(context).pop(scene);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final scene = widget.scene!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSceneQuestion(scene.name)),
        content: Text(l10n.deleteSceneDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final scope = AppScope.of(context);
    // Leave first, past the deleted scene's player too if it was open, so
    // nothing on screen still shows the scene.
    final navigator = Navigator.of(context)..pop();
    navigator
        .popUntil((route) => route.settings.name != playerRouteName(scene.id));
    if (scope.playback.effect.id == scene.id) {
      await scope.playback.stop();
    }
    await scope.preferences.deleteUserScene(scene.id);
  }

  Future<void> _pickColor(int? index) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(
        selected: index == null ? null : _colors[index],
      ),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _colors = [..._colors];
      if (index == null) {
        _colors.add(picked);
      } else {
        _colors[index] = picked;
      }
    });
  }

  /// Takes the colours of a photo the user chooses or takes.
  Future<void> _fromPhoto() async {
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.choosePhoto),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    try {
      final bytes = await scope.photos.pick(source);
      if (bytes == null || !mounted) {
        return;
      }
      final colors = await paletteFromImage(bytes, count: UserScene.maxColors);
      if (mounted) {
        setState(() => _colors = colors);
      }
    } on Object catch (error) {
      debugPrint('Scene from a photo: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canSave =
        _name.text.trim().isNotEmpty && _colors.length >= UserScene.minColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scene == null ? l10n.newScene : l10n.editScene),
        actions: [
          if (widget.scene != null)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          EffectPreview(
            effect: _draft.toEffect(),
            label: l10n.scenePreview,
            speed: 3,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.name,
              hintText: l10n.sceneNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child:
                    Text(l10n.sceneColors, style: theme.textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: _fromPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.sceneFromPhoto),
              ),
            ],
          ),
          Text(l10n.sceneColorsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, hex) in _colors.indexed)
                ColorSlot(
                  color: LightColor.fromHex(hex).toColor(),
                  label: l10n.sceneColorNumber(i + 1),
                  onTap: () => _pickColor(i),
                  onRemove: _colors.length > UserScene.minColors
                      ? () =>
                          setState(() => _colors = [..._colors]..removeAt(i))
                      : null,
                  removeLabel: l10n.remove,
                ),
              if (_colors.length < UserScene.maxColors)
                Semantics(
                  label: l10n.addColor,
                  button: true,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => _pickColor(null),
                    radius: 32,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.sceneMotion, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final motion in SceneMotion.values)
                ChoiceChip(
                  label: Text(sceneMotionName(l10n, motion)),
                  selected: _motion == motion,
                  onSelected: (_) => setState(() => _motion = motion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The name of [motion] in the editors.
String sceneMotionName(AppLocalizations l10n, SceneMotion motion) =>
    switch (motion) {
      SceneMotion.calm => l10n.motionCalm,
      SceneMotion.drift => l10n.motionDrift,
      SceneMotion.lively => l10n.motionLively,
      SceneMotion.flicker => l10n.motionFlicker,
    };

/// A colour to tap and change, with a button under it to remove it.
class ColorSlot extends StatelessWidget {
  const ColorSlot({
    required this.color,
    required this.label,
    required this.onTap,
    required this.onRemove,
    required this.removeLabel,
    super.key,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          button: true,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 32,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white38, width: 2),
              ),
            ),
          ),
        ),
        // Under the colour, so it never covers it.
        SizedBox(
          height: 48,
          child: onRemove == null
              ? null
              : Semantics(
                  label: '$removeLabel $label',
                  button: true,
                  excludeSemantics: true,
                  child: IconButton(
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
                ),
        ),
      ],
    );
  }
}

/// The swatches to choose a colour from; pops the chosen `#RRGGBB`.
class ColorPickerDialog extends StatelessWidget {
  const ColorPickerDialog({required this.selected, super.key});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.chooseColor),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, hex) in SceneEditor.swatches.indexed)
              Semantics(
                label: l10n.sceneSwatch(i + 1),
                selected: hex == selected,
                button: true,
                excludeSemantics: true,
                child: InkResponse(
                  onTap: () => Navigator.of(context).pop(hex),
                  radius: 26,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LightColor.fromHex(hex).toColor(),
                      border: Border.all(
                        color: hex == selected ? Colors.white : Colors.white24,
                        width: hex == selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// Five lamps showing a draft as it would play, [speed] times faster so
/// a slow motion can be judged at a glance. With [showTime], a bar shows
/// where in the timeline the preview is.
class EffectPreview extends StatefulWidget {
  const EffectPreview({
    required this.effect,
    required this.label,
    this.speed = 1,
    this.showTime = false,
    this.softFlashes = false,
    super.key,
  });

  final LightingEffect effect;
  final String label;
  final double speed;
  final bool showTime;

  /// Flashes rise and fall gently, as on the lights with the setting on.
  final bool softFlashes;

  @override
  State<EffectPreview> createState() => EffectPreviewState();
}

class EffectPreviewState extends State<EffectPreview>
    with SingleTickerProviderStateMixin {
  static const _lamps = 5;
  late final Ticker _ticker = createTicker(_tick);
  late EffectRenderer _renderer = _rendererFor(widget.effect);
  Duration _elapsed = Duration.zero;

  /// The ticker time and the effect time of the last [seek].
  Duration _origin = Duration.zero;
  Duration _from = Duration.zero;
  List<LightFrame> _frames = List.filled(_lamps, LightFrame.off);

  static EffectRenderer _rendererFor(LightingEffect effect) =>
      EffectRenderer(effect, slotCount: _lamps, seed: 3);

  Duration get _time => _from + (_elapsed - _origin) * widget.speed;

  @override
  void initState() {
    super.initState();
    _frames = _renderer.render(Duration.zero);
    if (!(WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations)) {
      unawaited(_ticker.start());
    }
  }

  @override
  void didUpdateWidget(EffectPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _renderer = _rendererFor(widget.effect);
    _frames = _renderer.render(_time);
  }

  /// Plays on from [position] into the effect.
  void seek(Duration position) {
    setState(() {
      _from = position;
      _origin = _elapsed;
      _frames = _renderer.render(_time);
    });
  }

  void _tick(Duration elapsed) {
    final step = elapsed - _elapsed;
    _elapsed = elapsed;
    final rendered = _renderer.render(_time);
    setState(() => _frames = widget.softFlashes
        ? softenFrames(_frames, rendered, step.inMicroseconds / 1e6)
        : rendered);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycle = widget.effect.cycleLength;
    final showTime = widget.showTime && cycle > Duration.zero;
    final position = showTime
        ? Duration(
            microseconds: _time.inMicroseconds % cycle.inMicroseconds,
          )
        : Duration.zero;
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 24, 16, showTime ? 12 : 24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final frame in _frames)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: frame.toDisplayColor(),
                      boxShadow: [
                        BoxShadow(
                          color: frame.color
                              .toColor()
                              .withValues(alpha: frame.brightness * 0.8),
                          blurRadius: 20 * frame.brightness,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (showTime) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    formatClock(position),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: position.inMicroseconds / cycle.inMicroseconds,
                      color: Colors.white70,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `m:ss`, for times in a story.
String formatClock(Duration time) {
  final seconds = time.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
