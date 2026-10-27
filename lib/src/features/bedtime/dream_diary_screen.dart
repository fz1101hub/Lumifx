import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/speech/voice_recordings.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'dream_diary.dart';

/// Shows [dream] in the room.
Future<void> showDream(BuildContext context, Dream dream) async {
  final playback = AppScope.of(context).playback;
  await playback.switchEffect(dream.effect(context.l10n.dreamDiary));
  if (playback.status == PlaybackStatus.idle) {
    await playback.start();
  } else if (playback.status == PlaybackStatus.paused) {
    await playback.resume();
  }
}

/// The dream diary: each child's dreams, newest first, told in the
/// morning in words (and their voice), shown in the room in their colours.
class DreamDiaryScreen extends StatelessWidget {
  const DreamDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dreamDiary)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DreamEditorScreen())),
        icon: const Icon(Icons.add),
        label: Text(l10n.dreamNew),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [preferences, if (scope.voices case final voices?) voices]),
        builder: (context, _) {
          final dreams = preferences.dreamsOf(preferences.activeChildId);
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.dreamDiaryDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (dreams.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l10n.dreamNone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge),
                ),
              for (final dream in dreams) _DreamCard(dream),
              const SizedBox(height: 72),
            ],
          );
        },
      ),
    );
  }
}

class _DreamCard extends StatelessWidget {
  const _DreamCard(this.dream);

  final Dream dream;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final recording = scope.voices?.pathOf(dream.recordingKey, 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      DateFormat.MMMMEEEEd(l10n.localeName).format(dream.date),
                      style: theme.textTheme.labelLarge),
                ),
                for (final color in dream.colors)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: CircleAvatar(
                        radius: 8,
                        backgroundColor: LightColor.fromHex(color).toColor()),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            if (dream.words.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(dream.words, style: theme.textTheme.bodyLarge),
            ],
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => showDream(context, dream),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(l10n.dreamShow),
                ),
                if (recording != null)
                  TextButton.icon(
                    onPressed: () => scope.voicePlayer.play(recording),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.dreamListen),
                  ),
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.dreamDeleteQuestion),
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
                    if (confirmed == true) {
                      await scope.voices?.deleteStory(dream.recordingKey);
                      await scope.preferences.deleteDream(dream.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Telling a dream: words, the voice if the child likes, and its colours
/// shown as they are found.
class DreamEditorScreen extends StatefulWidget {
  const DreamEditorScreen({super.key});

  /// The longest a dream told aloud may be.
  static const maxRecording = Duration(seconds: 90);

  @override
  State<DreamEditorScreen> createState() => _DreamEditorScreenState();
}

class _DreamEditorScreenState extends State<DreamEditorScreen> {
  final _id = Dream.newId();
  final _words = TextEditingController();
  late VoiceRecordings _voices;
  late VoiceRecorder _recorder;
  var _recording = false;
  var _saved = false;
  Timer? _limit;

  @override
  void initState() {
    super.initState();
    _words.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _voices = scope.voices ?? NoVoiceRecordings();
    _recorder = scope.voiceRecorder;
  }

  @override
  void dispose() {
    _limit?.cancel();
    if (_recording) {
      unawaited(_recorder.stop());
    }
    if (!_saved) {
      // Told but not kept: the voice goes too.
      unawaited(_voices.deleteStory(Dream.recordingKeyOf(_id)));
    }
    _words.dispose();
    super.dispose();
  }

  Dream get _draft => Dream.told(
        id: _id,
        child: AppScope.of(context).preferences.activeChildId,
        date: AppScope.of(context).clock(),
        words: _words.text,
      );

  Future<void> _record() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_recording) {
      await _stop();
      return;
    }
    if (!await _recorder.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.recordingDenied)));
      return;
    }
    try {
      final path = await _voices.newPath(Dream.recordingKeyOf(_id), 0);
      await _recorder.start(path);
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      setState(() => _recording = true);
      _limit = Timer(DreamEditorScreen.maxRecording, () => unawaited(_stop()));
    } on Object catch (error) {
      debugPrint('Dream recording: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.recordingDenied)));
    }
  }

  Future<void> _stop() async {
    _limit?.cancel();
    _limit = null;
    if (!_recording) {
      return;
    }
    await _recorder.stop();
    _voices.saved(Dream.recordingKeyOf(_id), 0);
    if (mounted) {
      setState(() => _recording = false);
    }
  }

  Future<void> _save() async {
    await _stop();
    if (!mounted) {
      return;
    }
    final dream = _draft;
    _saved = true;
    await AppScope.of(context).preferences.saveDream(dream);
    if (mounted) {
      await showDream(context, dream);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final draft = _draft;
    final hasVoice = _voices.pathOf(Dream.recordingKeyOf(_id), 0) != null;
    final canSave = draft.words.isNotEmpty || hasVoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dreamNew),
        actions: [
          TextButton(
            onPressed: canSave && !_recording ? _save : null,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          TextField(
            controller: _words,
            maxLines: 5,
            maxLength: Dream.maxWords,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.dreamWords,
              hintText: l10n.dreamWordsHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in draft.colors)
                CircleAvatar(
                    radius: 16,
                    backgroundColor: LightColor.fromHex(color).toColor()),
              TextButton.icon(
                onPressed: () => showDream(context, draft),
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(l10n.dreamShow),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor:
                  _recording ? theme.colorScheme.errorContainer : null,
            ),
            onPressed: _record,
            icon: Icon(_recording ? Icons.stop : Icons.mic_none),
            label: Text(_recording ? l10n.stopRecording : l10n.dreamRecord),
          ),
          if (hasVoice && !_recording) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => AppScope.of(context)
                    .voicePlayer
                    .play(_voices.pathOf(Dream.recordingKeyOf(_id), 0)!),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.dreamListen),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
