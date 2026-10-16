import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import 'scene_editor.dart';
import 'user_scene.dart';
import 'user_story.dart';

/// Creates a story of the user's own, or edits [story]: a name, background
/// colours, a length and moments on a timeline, each with words to read
/// along, with a live preview that can start from any moment.
class StoryEditor extends StatefulWidget {
  const StoryEditor({this.story, super.key});

  final UserStory? story;

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  late final _name = TextEditingController(text: widget.story?.name ?? '');
  late List<String> _colors =
      widget.story?.colors ?? const ['#0B1E5B', '#3A2A8C', '#0E6B7A'];
  late SceneMotion _motion = widget.story?.motion ?? SceneMotion.drift;
  late int _length = widget.story?.length ?? UserStory.defaultLength;
  late List<StoryMoment> _moments = widget.story?.moments ?? const [];
  final _preview = GlobalKey<EffectPreviewState>();

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

  UserStory _story(String id) => UserStory(
        id: id,
        name: UserStory.clip(_name.text, UserStory.maxName),
        colors: _colors,
        motion: _motion,
        length: _length,
        moments: _moments,
      );

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final story = _story(widget.story?.id ?? UserStory.newId());
    await scope.preferences.saveUserStory(story);
    // Playing it right now: show the edit on the lights at once.
    final playback = scope.playback;
    final edited = scope.library.byId(story.id);
    if (edited != null &&
        playback.effect.id == story.id &&
        playback.status != PlaybackStatus.idle) {
      await playback.switchEffect(edited);
    }
    if (mounted) {
      Navigator.of(context).pop(story);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final story = widget.story!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSceneQuestion(story.name)),
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
    // Leave first, past the deleted story's player too if it was open.
    final navigator = Navigator.of(context)..pop();
    navigator
        .popUntil((route) => route.settings.name != playerRouteName(story.id));
    if (scope.playback.effect.id == story.id) {
      await scope.playback.stop();
    }
    await scope.preferences.deleteUserStory(story.id);
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

  Future<void> _editMoment(int? index) async {
    final moment = index == null
        ? StoryMoment(
            at: _moments.isEmpty
                ? 0
                : (_moments.last.at + 5).clamp(0, _length - 1),
            kind: StoryMomentKind.spark,
          )
        : _moments[index];
    final result = await showDialog<_MomentResult>(
      context: context,
      builder: (_) => _MomentDialog(
        moment: moment,
        length: _length,
        isNew: index == null,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final moments = [..._moments];
      if (index != null) {
        moments.removeAt(index);
      }
      if (result.moment case final edited?) {
        moments.add(edited);
      }
      moments.sort((a, b) => a.at.compareTo(b.at));
      _moments = moments;
    });
    if (result.moment case final edited?) {
      _preview.currentState?.seek(Duration(seconds: edited.at));
    }
  }

  /// The story can be no shorter than its last moment.
  int get _shortest {
    final last = _moments.isEmpty ? 0 : _moments.last.at + 1;
    final rounded = (last + 9) ~/ 10 * 10;
    return rounded < UserStory.minLength ? UserStory.minLength : rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    final canSave =
        _name.text.trim().isNotEmpty && _colors.length >= UserScene.minColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story == null ? l10n.newStory : l10n.editStory),
        actions: [
          if (widget.story != null)
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
            key: _preview,
            effect: _story(widget.story?.id ?? '${UserStory.idPrefix}draft')
                .toEffect(),
            label: l10n.storyPreview,
            showTime: true,
            softFlashes: preferences.softFlashes,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: UserStory.maxName,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.name,
              hintText: l10n.storyNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.sceneColors, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.storyBackgroundHint, style: theme.textTheme.bodySmall),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 24),
          Text(
            l10n.storyLength(formatClock(Duration(seconds: _length))),
            style: theme.textTheme.titleSmall,
          ),
          Text(l10n.storyLengthHint, style: theme.textTheme.bodySmall),
          Slider(
            value: _length.toDouble(),
            min: UserStory.minLength.toDouble(),
            max: UserStory.maxLength.toDouble(),
            divisions: (UserStory.maxLength - UserStory.minLength) ~/ 10,
            label: formatClock(Duration(seconds: _length)),
            semanticFormatterCallback: (v) =>
                formatClock(Duration(seconds: v.round())),
            onChanged: (v) => setState(
              () => _length = v.round() < _shortest ? _shortest : v.round(),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.storyMoments, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.storyMomentsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (_moments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.noMomentsYet),
            ),
          for (final (i, moment) in _moments.indexed)
            _MomentTile(
              moment: moment,
              onTap: () => _editMoment(i),
              onPreview: () =>
                  _preview.currentState?.seek(Duration(seconds: moment.at)),
            ),
          const SizedBox(height: 8),
          if (_moments.length < UserStory.maxMoments)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _editMoment(null),
                icon: const Icon(Icons.add),
                label: Text(l10n.addMoment),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// The name of a kind of moment.
String momentKindName(AppLocalizations l10n, StoryMomentKind kind) =>
    switch (kind) {
      StoryMomentKind.spark => l10n.momentSpark,
      StoryMomentKind.spell => l10n.momentSpell,
      StoryMomentKind.wander => l10n.momentWander,
      StoryMomentKind.whoosh => l10n.momentWhoosh,
      StoryMomentKind.sparkles => l10n.momentSparkles,
      StoryMomentKind.darkness => l10n.momentDarkness,
      StoryMomentKind.lightning => l10n.momentLightning,
      StoryMomentKind.footsteps => l10n.momentFootsteps,
      StoryMomentKind.wordsOnly => l10n.momentWordsOnly,
    };

IconData _iconOf(StoryMomentKind kind) => switch (kind) {
      StoryMomentKind.spark => Icons.flare,
      StoryMomentKind.spell => Icons.auto_fix_high,
      StoryMomentKind.wander => Icons.gesture,
      StoryMomentKind.whoosh => Icons.air,
      StoryMomentKind.sparkles => Icons.auto_awesome,
      StoryMomentKind.darkness => Icons.dark_mode_outlined,
      StoryMomentKind.lightning => Icons.bolt,
      StoryMomentKind.footsteps => Icons.directions_walk,
      StoryMomentKind.wordsOnly => Icons.notes,
    };

class _MomentTile extends StatelessWidget {
  const _MomentTile({
    required this.moment,
    required this.onTap,
    required this.onPreview,
  });

  final StoryMoment moment;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = moment.kind.hasColor
        ? LightColor.fromHex(moment.effectiveColor).toColor()
        : theme.colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor:
              ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
          child: Icon(_iconOf(moment.kind)),
        ),
        title: Text(
          '${formatClock(Duration(seconds: moment.at))}  '
          '${momentKindName(l10n, moment.kind)}',
        ),
        subtitle: moment.words.isEmpty
            ? null
            : Text(
                moment.words,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: IconButton(
          tooltip: l10n.playFromHere,
          icon: const Icon(Icons.play_circle_outline),
          onPressed: onPreview,
        ),
      ),
    );
  }
}

/// The moment edited ([moment]), or removed (null).
class _MomentResult {
  const _MomentResult(this.moment);

  final StoryMoment? moment;
}

class _MomentDialog extends StatefulWidget {
  const _MomentDialog({
    required this.moment,
    required this.length,
    required this.isNew,
  });

  final StoryMoment moment;
  final int length;
  final bool isNew;

  @override
  State<_MomentDialog> createState() => _MomentDialogState();
}

class _MomentDialogState extends State<_MomentDialog> {
  late int _at = widget.moment.at.clamp(0, widget.length - 1);
  late StoryMomentKind _kind = widget.moment.kind;
  late String _color = widget.moment.color;
  late final _words = TextEditingController(text: widget.moment.words);

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  Future<void> _pickColor() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(
        selected: _color.isEmpty ? _kind.defaultColor : _color,
      ),
    );
    if (picked != null) {
      setState(() => _color = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = formatClock(Duration(seconds: _at));
    final shown = _color.isEmpty ? _kind.defaultColor : _color;
    return AlertDialog(
      title: Text(l10n.editMoment),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.momentAt(time), style: theme.textTheme.titleSmall),
          Slider(
            value: _at.toDouble(),
            max: (widget.length - 1).toDouble(),
            divisions: widget.length - 1,
            label: time,
            semanticFormatterCallback: (v) =>
                formatClock(Duration(seconds: v.round())),
            onChanged: (v) => setState(() => _at = v.round()),
          ),
          const SizedBox(height: 8),
          Text(l10n.momentWhat, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final kind in StoryMomentKind.values)
                ChoiceChip(
                  avatar: Icon(_iconOf(kind), size: 18),
                  label: Text(momentKindName(l10n, kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          if (_kind.hasColor) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(l10n.momentColor, style: theme.textTheme.titleSmall),
                const SizedBox(width: 16),
                Semantics(
                  label: l10n.chooseColor,
                  button: true,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: _pickColor,
                    radius: 28,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LightColor.fromHex(shown).toColor(),
                        border: Border.all(color: Colors.white38, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _words,
            maxLength: UserStory.maxWords,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.momentWords,
              hintText: l10n.momentWordsHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.isNew)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _MomentResult(null)),
            child: Text(l10n.remove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _MomentResult(
              StoryMoment(
                at: _at,
                kind: _kind,
                color: _kind.hasColor ? _color : '',
                words: UserStory.clip(_words.text, UserStory.maxWords),
              ),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
