import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/links/app_link.dart';

void main() {
  test('full links and path-only links mean the same', () {
    for (final location in [
      'lumifx://app/play/ocean?room=Living%20room',
      '/play/ocean?room=Living%20room',
    ]) {
      final link = AppLink.parse(location);
      expect(link, isA<EffectLink>());
      link as EffectLink;
      expect(link.effectId, 'ocean');
      expect(link.start, isTrue);
      expect(link.room, 'Living room');
      expect(link.area, isNull);
    }
  });

  test('open, playlist and stop', () {
    final open = AppLink.parse('lumifx://app/open/aurora')! as EffectLink;
    expect(open.start, isFalse);
    final playlist =
        AppLink.parse('lumifx://app/playlist/Movie%20night')! as PlaylistLink;
    expect(playlist.nameOrId, 'Movie night');
    expect(AppLink.parse('lumifx://app/stop'), isA<StopLink>());
    final area =
        AppLink.parse('/play/thunderstorm?area=TV%20area&room=')! as EffectLink;
    expect(area.area, 'TV area');
    expect(area.room, isNull, reason: 'an empty parameter is no parameter');
  });

  test('anything else is not a link', () {
    expect(AppLink.parse('/'), isNull);
    expect(AppLink.parse('https://example.com/play/ocean'), isNull);
    expect(AppLink.parse('lumifx://app/dance'), isNull);
    expect(AppLink.parse('lumifx://app/play'), isNull);
  });

  test('copied links parse back', () {
    final play = AppLink.parse(AppLink.play('ocean', room: 'Den & kitchen'))!
        as EffectLink;
    expect(play.room, 'Den & kitchen');
    final playlist =
        AppLink.parse(AppLink.playlist('Rock & roll'))! as PlaylistLink;
    expect(playlist.nameOrId, 'Rock & roll');
    expect(AppLink.parse(AppLink.stop), isA<StopLink>());
  });

  test('bedtime, and what a voice assistant heard', () {
    expect(AppLink.parse(AppLink.bedtime), isA<BedtimeLink>());
    final voice = AppLink.parse('lumifx://app/voice/feu%20de%20chemin%C3%A9e')!
        as VoiceLink;
    expect(voice.words, 'feu de cheminée');
    expect(AppLink.parse('lumifx://app/voice/%20'), isNull);
  });

  test('screen links open the family screens by name', () {
    for (final screen in AppScreen.values) {
      final link = AppLink.parse(AppLink.go(screen));
      expect(link, isA<ScreenLink>());
      expect((link! as ScreenLink).screen, screen);
    }
    expect((AppLink.parse('/go/Star-Shop')! as ScreenLink).screen,
        AppScreen.starShop);
    expect(AppLink.parse('lumifx://app/go/nowhere'), isNull);
    expect(AppLink.go(AppScreen.ritual), 'lumifx://app/go/ritual');
    expect(
        (AppLink.parse('lumifx://app/go/colour-mixing')! as ScreenLink).screen,
        AppScreen.colourMixing);
    expect(AppScreen.values.map((s) => s.slug).toSet(),
        hasLength(AppScreen.values.length),
        reason: 'every slug its own');
  });

  test('a family sync link carries the address and the code', () {
    final link = AppLink.parse(AppLink.sync('192.168.1.20', 40123, '123456'));
    expect(link, isA<SyncLink>());
    final sync = link! as SyncLink;
    expect(
        (sync.host, sync.port, sync.code), ('192.168.1.20', 40123, '123456'));
    expect(AppLink.parse('lumifx://app/sync?h=1.2.3.4&c=1'), isNull,
        reason: 'no port');
  });
}
