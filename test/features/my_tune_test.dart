import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/links/app_link.dart';
import 'package:lumifx/src/features/music_box/my_tune.dart';

void main() {
  const tune = MyTune(name: 'Mia song', notes: [
    (Duration.zero, 0),
    (Duration(milliseconds: 400), 2),
    (Duration(milliseconds: 1250), 4),
  ]);

  test('a tune is kept and shared as text, with its own timing', () {
    expect(tune.encoded, '0.0,40.2,85.4');
    final back = MyTune.decode('Mia song', tune.encoded)!;
    expect(back.notes, tune.notes);
    expect(MyTune.decode('', tune.encoded), isNull);
    expect(MyTune.decode('X', '1.9'), isNull, reason: 'no ninth key');
    expect(MyTune.decode('X', 'nonsense'), isNull);
  });

  test('the link carries the name and the notes', () {
    final link = AppLink.parse(AppLink.tune(tune.name, tune.encoded))!;
    expect(link, isA<TuneLink>());
    expect((link as TuneLink).name, 'Mia song');
    expect(link.data, tune.encoded);
  });

  test('tunes are kept, the same name replaced, ten at most', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    await first.saveTune(tune);
    await first.saveTune(const MyTune(name: 'Mia song', notes: [
      (Duration.zero, 7),
    ]));
    for (var i = 0; i < 12; i++) {
      await first.saveTune(MyTune(name: 'T$i', notes: const [
        (Duration.zero, 1),
      ]));
    }
    expect(first.myTunes, hasLength(MyTune.maxTunes));
    expect(first.myTunes.last.name, 'T11');
    await first.deleteTune('T11');
    final second = PreferencesController(store: store);
    await second.load();
    expect(second.myTunes.map((t) => t.name), isNot(contains('T11')));
    expect(second.myTunes, hasLength(MyTune.maxTunes - 1));
  });
}
