import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/family/family_sync.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/routines/child.dart';

UserScene _scene(String id, String name) => UserScene(
    id: '${UserScene.idPrefix}$id',
    name: name,
    colors: const ['#FF0000', '#00FF00']);

void main() {
  test('both phones end up with the same things', () {
    final a = FamilyBundle(
      scenes: [_scene('1', 'Sunset'), _scene('2', 'Old name')],
      favorites: const ['ocean'],
      children: const [Child(id: '', name: 'Mia')],
    );
    final b = FamilyBundle(
      scenes: [_scene('2', 'New name'), _scene('3', 'Forest')],
      favorites: const ['fire', 'ocean'],
      children: const [
        Child(id: '', name: 'Mia'),
        Child(id: 'c2', name: 'Leo')
      ],
    );
    final onA = FamilyBundle.merge(a, b);
    final onB = FamilyBundle.merge(b, a);
    String names(FamilyBundle x) =>
        ([for (final s in x.scenes) '${s.id}=${s.name}']..sort()).join(',');
    expect(names(onA.merged), names(onB.merged),
        reason: 'the same version wins on both');
    expect(onA.merged.scenes, hasLength(3));
    expect(onA.merged.favorites, ['ocean', 'fire']);
    expect([for (final c in onA.merged.children) c.name], ['Mia', 'Leo']);
    expect(onA.changes, greaterThan(0));
    expect(FamilyBundle.merge(onA.merged, onB.merged).changes, 0,
        reason: 'once in sync, nothing more to do');
  });

  test('two phones exchange their things over the home network', () async {
    final host = PreferencesController(store: InMemoryKeyValueStore());
    await host.saveUserScene(_scene('1', 'Sunset'));
    await host.toggleFavorite('ocean');
    final guest = PreferencesController(store: InMemoryKeyValueStore());
    await guest.saveUserScene(_scene('3', 'Forest'));
    await guest.addChild('Leo');

    var joined = 0;
    final sharing = FamilySyncHost(
      mine: () => FamilyBundle.of(host),
      onJoined: (theirs) async =>
          joined += await FamilyBundle.mergeInto(host, theirs),
      code: '123456',
    );
    await sharing.start(InternetAddress.loopbackIPv4);
    addTearDown(sharing.stop);

    await expectLater(
        FamilySync.join(
            '127.0.0.1', sharing.port!, '654321', FamilyBundle.of(guest)),
        throwsA(anything),
        reason: 'a wrong code gets nothing');

    final theirs = await FamilySync.join(
        '127.0.0.1', sharing.port!, '123456', FamilyBundle.of(guest));
    await FamilyBundle.mergeInto(guest, theirs);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    for (final phone in [host, guest]) {
      expect({for (final s in phone.userScenes) s.name}, {'Sunset', 'Forest'});
      expect(phone.favorites, ['ocean']);
      expect([for (final c in phone.children) c.name], ['Leo']);
    }
    expect(joined, greaterThan(0));
  });
}
