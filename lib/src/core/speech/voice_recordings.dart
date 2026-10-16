import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Lines of a user's story read in their own voice: one sound file per
/// moment, keyed by the story and the second the moment comes at. The
/// files stay on the phone.
abstract class VoiceRecordings extends ChangeNotifier {
  Future<void> load();

  /// The file of the line at [at] seconds into [storyId], if recorded.
  String? pathOf(String storyId, int at);

  bool hasAny(String storyId);

  /// Where to record the line at [at]; [saved] makes it count.
  Future<String> newPath(String storyId, int at);

  void saved(String storyId, int at);

  Future<void> delete(String storyId, int at);

  Future<void> deleteStory(String storyId);
}

/// For tests and platforms without files.
class NoVoiceRecordings extends VoiceRecordings {
  @override
  Future<void> load() async {}

  @override
  String? pathOf(String storyId, int at) => null;

  @override
  bool hasAny(String storyId) => false;

  @override
  Future<String> newPath(String storyId, int at) =>
      Future.error(UnsupportedError('No recordings here'));

  @override
  void saved(String storyId, int at) {}

  @override
  Future<void> delete(String storyId, int at) async {}

  @override
  Future<void> deleteStory(String storyId) async {}
}

/// Recordings as files under [root]: `<story>/<second>.m4a`.
class FileVoiceRecordings extends VoiceRecordings {
  FileVoiceRecordings([Future<Directory> Function()? root])
      : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;
  Directory? _dir;

  /// Story folder name → seconds recorded.
  final _index = <String, Set<int>>{};

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/voices');

  /// A file-safe name for a story id.
  static String folderOf(String storyId) =>
      storyId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Directory> _ready() async => _dir ??= await _root();

  @override
  Future<void> load() async {
    try {
      final dir = await _ready();
      _index.clear();
      if (!dir.existsSync()) {
        return;
      }
      for (final story in dir.listSync().whereType<Directory>()) {
        final name = story.uri.pathSegments.where((s) => s.isNotEmpty).last;
        for (final file in story.listSync().whereType<File>()) {
          final match = RegExp(r'(\d+)\.m4a$').firstMatch(file.path);
          if (match != null && file.lengthSync() > 0) {
            (_index[name] ??= {}).add(int.parse(match.group(1)!));
          }
        }
      }
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Voices: $error');
    }
  }

  String _path(Directory dir, String storyId, int at) =>
      '${dir.path}/${folderOf(storyId)}/$at.m4a';

  @override
  String? pathOf(String storyId, int at) {
    final dir = _dir;
    if (dir == null || !(_index[folderOf(storyId)]?.contains(at) ?? false)) {
      return null;
    }
    return _path(dir, storyId, at);
  }

  @override
  bool hasAny(String storyId) => _index[folderOf(storyId)]?.isNotEmpty ?? false;

  @override
  Future<String> newPath(String storyId, int at) async {
    final dir = await _ready();
    final folder = Directory('${dir.path}/${folderOf(storyId)}');
    await folder.create(recursive: true);
    return _path(dir, storyId, at);
  }

  @override
  void saved(String storyId, int at) {
    (_index[folderOf(storyId)] ??= {}).add(at);
    notifyListeners();
  }

  @override
  Future<void> delete(String storyId, int at) async {
    final dir = await _ready();
    final file = File(_path(dir, storyId, at));
    if (file.existsSync()) {
      await file.delete();
    }
    _index[folderOf(storyId)]?.remove(at);
    notifyListeners();
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final dir = await _ready();
    final folder = Directory('${dir.path}/${folderOf(storyId)}');
    if (folder.existsSync()) {
      await folder.delete(recursive: true);
    }
    _index.remove(folderOf(storyId));
    notifyListeners();
  }
}

/// Records a line from the microphone.
abstract interface class VoiceRecorder {
  /// Asks for the microphone if needed; false if refused.
  Future<bool> requestPermission();

  Future<void> start(String path);

  Future<void> stop();
}

class NoVoiceRecorder implements VoiceRecorder {
  const NoVoiceRecorder();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> start(String path) async {}

  @override
  Future<void> stop() async {}
}

/// AAC in an .m4a file, mono, as clear as a voice needs.
class PluginVoiceRecorder implements VoiceRecorder {
  PluginVoiceRecorder();

  AudioRecorder? _recorder;

  @override
  Future<bool> requestPermission() =>
      (_recorder ??= AudioRecorder()).hasPermission();

  @override
  Future<void> start(String path) => (_recorder ??= AudioRecorder()).start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 96000,
        ),
        path: path,
      );

  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }
}

/// Plays a recorded line.
abstract interface class VoicePlayer {
  Future<void> play(String path);

  Future<void> stop();
}

class NoVoicePlayer implements VoicePlayer {
  const NoVoicePlayer();

  @override
  Future<void> play(String path) async {}

  @override
  Future<void> stop() async {}
}

class AudioplayersVoicePlayer implements VoicePlayer {
  AudioplayersVoicePlayer();

  final _player = AudioPlayer();

  @override
  Future<void> play(String path) async {
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } on Object catch (error) {
      debugPrint('Voice: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // Nothing was playing.
    }
  }
}
