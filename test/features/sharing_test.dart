import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/library/sharing.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/links/app_link.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';

void main() {
  const scene = UserScene(
    id: 'user:1',
    name: 'Embers & ash',
    colors: ['#FF2D2D', '#FF9A2E', '#222222'],
    motion: SceneMotion.flicker,
  );
  const playlist = Playlist(
    id: 'p1',
    name: 'Évening',
    effectIds: ['ocean', 'user:1'],
    each: Duration(minutes: 15),
    shuffle: true,
  );

  test('a bundle survives the link and comes back the same', () {
    const bundle = SharedBundle(scenes: [scene], playlists: [playlist]);
    final link = bundle.link;
    expect(link, startsWith('lumifx://app/import?d='));
    expect(link.contains('='), isTrue);
    expect(link.substring(link.indexOf('d=') + 2), isNot(contains('=')),
        reason: 'no padding, so the link survives messengers');

    final parsed = AppLink.parse(link)! as ImportLink;
    final back = SharedBundle.decode(parsed.data)!;
    expect(back.scenes.single.name, 'Embers & ash');
    expect(back.scenes.single.colors, scene.colors);
    expect(back.scenes.single.motion, SceneMotion.flicker);
    expect(back.playlists.single.name, 'Évening');
    expect(back.playlists.single.effectIds, ['ocean', 'user:1']);
    expect(back.playlists.single.each, const Duration(minutes: 15));
    expect(back.playlists.single.shuffle, isTrue);
  });

  test('a backup of many scenes still fits a short link', () {
    final bundle = SharedBundle(scenes: [
      for (var i = 0; i < 20; i++)
        UserScene(
          id: 'user:$i',
          name: 'Scene $i',
          colors: const ['#FF2D2D', '#FF9A2E', '#FFC300', '#3DDC84'],
        ),
    ]);
    // Compression keeps it within what a QR code holds (about 2900 bytes).
    expect(bundle.link.length, lessThan(2000));
  });

  test('anything that is not a bundle is refused', () {
    expect(SharedBundle.decode('not-base64!'), isNull);
    expect(SharedBundle.decode(''), isNull);
    expect(SharedBundle.decode('eJwDAAAAAAE'), isNull, reason: 'empty data');
    expect(AppLink.parse('lumifx://app/import'), isNull);
  });
}
