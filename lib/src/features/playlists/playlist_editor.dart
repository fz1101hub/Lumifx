import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_palette.dart';
import 'playlist.dart';

/// Creates a playlist, or edits [playlist].
class PlaylistEditor extends StatefulWidget {
  const PlaylistEditor({this.playlist, super.key});

  final Playlist? playlist;

  @override
  State<PlaylistEditor> createState() => _PlaylistEditorState();
}

class _PlaylistEditorState extends State<PlaylistEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.playlist?.name ?? '');
  late List<String> _effectIds = [...?widget.playlist?.effectIds];
  late int _minutes = widget.playlist?.each.inMinutes ?? 10;
  late bool _shuffle = widget.playlist?.shuffle ?? false;

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

  bool get _canSave => _name.text.trim().isNotEmpty && _effectIds.isNotEmpty;

  Future<void> _save() async {
    final preferences = AppScope.of(context).preferences;
    final playlist = Playlist(
      id: widget.playlist?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      effectIds: _effectIds,
      each: Duration(minutes: _minutes),
      shuffle: _shuffle,
    );
    await preferences.savePlaylist(playlist);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final playlist = widget.playlist!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePlaylistQuestion(playlist.name)),
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
    if (scope.playback.playlist?.id == playlist.id) {
      await scope.playback.stop();
    }
    await scope.preferences.deletePlaylist(playlist.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addEffects() async {
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EffectPicker(initial: _effectIds),
    );
    if (chosen != null) {
      setState(() => _effectIds = chosen);
    }
  }

  void _move(int index, int by) {
    final target = index + by;
    if (target < 0 || target >= _effectIds.length) {
      return;
    }
    setState(() {
      final id = _effectIds.removeAt(index);
      _effectIds.insert(target, id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final library = AppScope.of(context).library;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.playlist == null ? l10n.newPlaylist : l10n.editPlaylist),
        actions: [
          if (widget.playlist != null)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.name,
              hintText: l10n.playlistNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.playlistEach, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final minutes in Playlist.durations)
                ChoiceChip(
                  label: Text(l10n.sleepTimerMinutes(minutes)),
                  selected: _minutes == minutes,
                  onSelected: (_) => setState(() => _minutes = minutes),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.shuffle),
            subtitle: Text(l10n.shuffleDescription),
            value: _shuffle,
            onChanged: (value) => setState(() => _shuffle = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.effectCount(_effectIds.length),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: _addEffects,
                icon: const Icon(Icons.playlist_add),
                label: Text(l10n.chooseEffects),
              ),
            ],
          ),
          for (final (index, id) in _effectIds.indexed)
            if (library.byId(id) case final effect?)
              ListTile(
                key: ValueKey('$index-$id'),
                contentPadding: EdgeInsets.zero,
                leading: _Swatch(effect),
                title: Text(l10n.effectName(effect)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.moveUp,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: index == 0 ? null : () => _move(index, -1),
                    ),
                    IconButton(
                      tooltip: l10n.moveDown,
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index == _effectIds.length - 1
                          ? null
                          : () => _move(index, 1),
                    ),
                    IconButton(
                      tooltip: l10n.remove,
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _effectIds.removeAt(index)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.effect);

  final LightingEffect effect;

  @override
  Widget build(BuildContext context) {
    final colors = effectPalette(effect);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: colors.length > 1 ? colors : [...colors, ...colors],
        ),
      ),
    );
  }
}

/// Every effect, grouped by kind, with a tick box each.
class _EffectPicker extends StatefulWidget {
  const _EffectPicker({required this.initial});

  final List<String> initial;

  @override
  State<_EffectPicker> createState() => _EffectPickerState();
}

class _EffectPickerState extends State<_EffectPicker> {
  late final List<String> _chosen = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = AppScope.of(context).library;
    final theme = Theme.of(context);
    final sections = [
      (l10n.myScenes, library.userScenes),
      (l10n.scenes, library.ofKind(EffectKind.scene, builtInOnly: true)),
      (l10n.stories, library.ofKind(EffectKind.story)),
      (l10n.interactive, library.ofKind(EffectKind.interactive)),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (final (title, effects) in sections)
                  if (effects.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    for (final effect in effects)
                      CheckboxListTile(
                        secondary: _Swatch(effect),
                        title: Text(l10n.effectName(effect)),
                        value: _chosen.contains(effect.id),
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            _chosen.add(effect.id);
                          } else {
                            _chosen.remove(effect.id);
                          }
                        }),
                      ),
                  ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_chosen),
                  child: Text(l10n.done),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
