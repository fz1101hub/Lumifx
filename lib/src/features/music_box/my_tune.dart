import 'light_piano.dart';

/// A tune played on the light piano and kept: when each key was pressed
/// and which. Kept and shared as text: for each note, the centiseconds
/// since the last note, a dot and the key (`25.3`), comma-separated.
class MyTune {
  const MyTune({required this.name, required this.notes});

  final String name;

  /// When (from the start) and which key (an index in `pianoKeys`).
  final List<(Duration, int)> notes;

  static const maxNotes = 400;
  static const maxTunes = 10;
  static const maxName = 30;

  String get encoded {
    final parts = <String>[];
    var last = Duration.zero;
    for (final (at, key) in notes.take(maxNotes)) {
      final gap = (at - last).inMilliseconds ~/ 10;
      parts.add('${gap.clamp(0, 99999)}.$key');
      last = at;
    }
    return parts.join(',');
  }

  /// The tune [data] stands for, or null if it is not one.
  static MyTune? decode(String name, String data) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxName) {
      return null;
    }
    final notes = <(Duration, int)>[];
    var at = Duration.zero;
    for (final part in data.split(',').take(maxNotes)) {
      final [gap, key, ...] = [...part.split('.'), '', ''];
      final centiseconds = int.tryParse(gap);
      final index = int.tryParse(key);
      if (centiseconds == null ||
          centiseconds < 0 ||
          index == null ||
          index < 0 ||
          index >= pianoKeys.length) {
        return null;
      }
      at += Duration(milliseconds: centiseconds * 10);
      notes.add((at, index));
    }
    return notes.isEmpty ? null : MyTune(name: trimmed, notes: notes);
  }
}
