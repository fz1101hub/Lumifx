import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/speech/voice_recordings.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'scene_editor.dart';
import 'user_story.dart';

/// Records the lines of a story in the user's own voice: when the story
/// plays, each recorded line is heard as the lights reach it.
class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({required this.story, super.key});

  final UserStory story;

  /// The longest a line may be.
  static const maxLength = Duration(seconds: 30);

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  late VoiceRecordings _voices;
  late VoiceRecorder _recorder;
  late VoicePlayer _player;
  int? _recording;
  Timer? _limit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _voices = scope.voices ?? NoVoiceRecordings();
    _recorder = scope.voiceRecorder;
    _player = scope.voicePlayer;
  }

  @override
  void dispose() {
    _limit?.cancel();
    if (_recording != null) {
      unawaited(_recorder.stop());
    }
    unawaited(_player.stop());
    super.dispose();
  }

  Future<void> _start(int at) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_recording != null) {
      await _stop();
    }
    await _player.stop();
    if (!await _recorder.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.recordingDenied)));
      return;
    }
    try {
      final path = await _voices.newPath(widget.story.id, at);
      await _recorder.start(path);
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      setState(() => _recording = at);
      _limit = Timer(VoiceRecordingScreen.maxLength, () => unawaited(_stop()));
    } on Object catch (error) {
      debugPrint('Recording: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.recordingDenied)));
    }
  }

  Future<void> _stop() async {
    final at = _recording;
    _limit?.cancel();
    _limit = null;
    if (at == null) {
      return;
    }
    await _recorder.stop();
    _voices.saved(widget.story.id, at);
    if (mounted) {
      setState(() => _recording = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lines = [
      for (final moment in widget.story.moments)
        if (moment.words.trim().isNotEmpty) moment,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordVoices)),
      body: ListenableBuilder(
        listenable: _voices,
        builder: (context, _) => ListView(
          padding: context.pageInsets(),
          children: [
            Text(l10n.recordVoicesDescription,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (lines.isEmpty) Text(l10n.recordingNoWords),
            for (final moment in lines)
              Builder(builder: (context) {
                final path = _voices.pathOf(widget.story.id, moment.at);
                final recording = _recording == moment.at;
                return Card(
                  color: recording ? theme.colorScheme.errorContainer : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatClock(Duration(seconds: moment.at)),
                              style: theme.textTheme.labelMedium,
                            ),
                            if (path != null && !recording) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.check_circle,
                                  size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(l10n.recorded,
                                  style: theme.textTheme.labelMedium),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(moment.words, style: theme.textTheme.titleMedium),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              if (recording)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                  ),
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop),
                                  label: Text(l10n.stopRecording),
                                )
                              else ...[
                                if (path != null) ...[
                                  IconButton(
                                    tooltip: l10n.playRecording,
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => _player.play(path),
                                  ),
                                  IconButton(
                                    tooltip: l10n.deleteRecording,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _voices.delete(
                                        widget.story.id, moment.at),
                                  ),
                                ],
                                FilledButton.tonalIcon(
                                  onPressed: () => _start(moment.at),
                                  icon: const Icon(Icons.mic),
                                  label: Text(l10n.recordLine),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
