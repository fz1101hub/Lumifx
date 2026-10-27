import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/guests/guest_remote.dart';

const _text = GuestPageText(
  title: 'Pick the lights',
  colours: 'Colours',
  effects: 'Effects',
  stop: 'Stop',
  done: 'Done!',
  wrongCode: 'Wrong code',
  language: 'en',
);

void main() {
  late GuestRemote remote;
  late Uri link;
  final picks = <GuestPick>[];
  var now = DateTime(2026, 10, 27, 20);
  final client = HttpClient();

  setUp(() async {
    picks.clear();
    remote = GuestRemote(
      effects: const [
        (id: 'ocean', name: 'Ocean'),
        (id: 'fire', name: 'Fire <3'),
      ],
      colors: const [(hex: '#FF2020', name: 'Red')],
      text: _text,
      onPick: picks.add,
      random: math.Random(4),
      clock: () => now,
    );
    link = await remote.start(InternetAddress.loopbackIPv4);
  });

  tearDown(() => remote.stop());

  Future<(int, String)> send(String method, Uri uri) async {
    final request = await client.openUrl(method, uri);
    final response = await request.close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  }

  Uri at(String path, Map<String, String> query) =>
      link.replace(path: path, queryParameters: query);

  test('the page needs the code, and lists the safe picks', () async {
    expect(remote.code, hasLength(6));
    expect(link.queryParameters['c'], remote.code);
    final (wrong, _) = await send('GET', at('/', {'c': '000000x'}));
    expect(wrong, HttpStatus.forbidden);
    final (status, page) = await send('GET', link);
    expect(status, HttpStatus.ok);
    expect(page, contains('Ocean'));
    expect(page, contains('Fire &lt;3'), reason: 'names are escaped');
    expect(page, contains('#FF2020'));
  });

  test('a guest picks from the list only, not too fast', () async {
    var (status, _) =
        await send('POST', at('/pick', {'c': remote.code, 'effect': 'ocean'}));
    expect(status, HttpStatus.noContent);
    (status, _) =
        await send('POST', at('/pick', {'c': remote.code, 'color': '#FF2020'}));
    expect(status, HttpStatus.tooManyRequests);
    now = now.add(const Duration(seconds: 2));
    (status, _) = await send(
        'POST', at('/pick', {'c': remote.code, 'effect': 'thunderstorm'}));
    expect(status, HttpStatus.badRequest, reason: 'not on the list');
    (status, _) =
        await send('POST', at('/pick', {'c': remote.code, 'color': '#FF2020'}));
    expect(status, HttpStatus.noContent);
    now = now.add(const Duration(seconds: 2));
    (status, _) = await send('POST', at('/pick', {'c': 'nope', 'stop': '1'}));
    expect(status, HttpStatus.forbidden);
    expect(
        [for (final p in picks) p.effectId ?? p.color], ['ocean', '#FF2020']);
  });

  test('stopped, nothing answers any more', () async {
    await remote.stop();
    expect(remote.isRunning, isFalse);
    await expectLater(send('GET', link), throwsA(isA<SocketException>()));
  });

  test('only home network addresses are offered', () {
    bool private(String a) => GuestRemote.isPrivate(InternetAddress(a));
    expect(private('192.168.1.20'), isTrue);
    expect(private('10.0.0.5'), isTrue);
    expect(private('172.20.1.1'), isTrue);
    expect(private('172.32.1.1'), isFalse);
    expect(private('8.8.8.8'), isFalse);
    expect(private('127.0.0.1'), isFalse);
  });
}
