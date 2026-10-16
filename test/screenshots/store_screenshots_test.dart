// Store screenshots, rendered by the widget test framework with the real
// Roboto and Material Icons fonts, in every language, at two phone sizes
// and on a 12.9" iPad. Off by default (it writes files): run with
//
//   LUMIFX_SCREENSHOTS=1 flutter test test/screenshots
//
// and find the PNGs under build/screenshots/<device>/<locale>/. The CI
// uploads them as the "store-screenshots" artifact.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';

final _enabled = Platform.environment['LUMIFX_SCREENSHOTS'] == '1';

/// Store sizes: Apple's 6.5" slot (accepted for every iPhone), an exact
/// 9:16 frame for Google Play, and the 12.9" iPad slot (required by the
/// App Store once the app runs on iPad; Play accepts it for tablets).
const _devices = {
  'iphone-6.5': (size: Size(1242, 2688), ratio: 3.0),
  'android-9x16': (size: Size(1080, 1920), ratio: 2.5),
  'ipad-12.9': (size: Size(2048, 2732), ratio: 2.0),
};

void main() {
  setUpAll(_loadFonts);

  for (final MapEntry(key: device, value: frame) in _devices.entries) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('$device ${locale.languageCode}', (tester) async {
        tester.view.physicalSize = frame.size;
        tester.view.devicePixelRatio = frame.ratio;
        addTearDown(tester.view.reset);
        await _capture(tester, device, locale);
      }, skip: !_enabled);
    }
  }
}

Future<void> _capture(WidgetTester tester, String device, Locale locale) async {
  final l10n = lookupAppLocalizations(locale);
  final bridge = await _demoBridge(tester);
  final preferences = PreferencesController(store: InMemoryKeyValueStore());
  await preferences.toggleFavorite('haunted_manor');
  await preferences.toggleFavorite('aurora');
  await preferences.recordPlayed('emerald_trickster');
  await preferences.recordPlayed('fireplace');
  await preferences.setFlashWarningShown(true);
  await preferences.setLastTarget('group:r1');
  await preferences.setVariant('aurora', 'rose_gold');

  final boundary = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: boundary,
    child: LumiFxApp(
      bridge: bridge,
      discovery: _NoDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      locale: locale,
    ),
  ));
  await tester.pumpAndSettle();
  Future<void> shot(String name) =>
      _save(tester, boundary, '$device/${locale.languageCode}/$name');
  Future<void> open(String text) async {
    // The outermost Scrollable is the page; shelves scroll sideways.
    await tester.scrollUntilVisible(find.text(text), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> back() async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  await shot('01-home');

  await open(l10n.stories);
  await shot('02-stories');
  await back();

  await open(l10n.scenes);
  await open(l10n.effectName(aurora));
  await tester.tap(find.text(l10n.play));
  // Let the lamps settle into the aurora (the player ticks on a timer).
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await shot('03-player');
  await tester.tap(find.text(l10n.stop));
  await tester.pumpAndSettle();
  await back();
  await back();

  await open(l10n.roomsAndZones);
  await shot('04-rooms');
  await back();

  await tester.tap(find.byTooltip(l10n.settings));
  await tester.pumpAndSettle();
  await open(l10n.entertainmentStreaming);
  await open('TV area');
  await shot('05-area-editor');
}

Future<void> _save(WidgetTester tester, GlobalKey boundary, String path) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image =
        await render.toImage(pixelRatio: tester.view.devicePixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screenshots/$path.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// The fonts the app uses, from the Flutter SDK, so text is not rendered
/// in the test framework's placeholder font.
Future<void> _loadFonts() async {
  if (!_enabled) {
    return;
  }
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final file = File('$fonts/$name');
      if (file.existsSync()) {
        loader.addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

class _NoDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      const Stream.empty();
}

/// A living room with three colour lights and a strip, a kitchen, a
/// downstairs zone, three Hue scenes and a TV entertainment area.
Future<BridgeController> _demoBridge(WidgetTester tester) async {
  http.Response json(Object body) => http.Response(jsonEncode(body), 200);
  Map<String, Object> light(String id, String device, String name,
          {double x = 0.4, double y = 0.4, double brightness = 70}) =>
      {
        'id': id,
        'owner': {'rid': device, 'rtype': 'device'},
        'metadata': {'name': name},
        'on': {'on': true},
        'dimming': {'brightness': brightness},
        'color': {
          'xy': {'x': x, 'y': y},
        },
      };
  Map<String, Object> entertainment(String id, String device, String light,
          {int streams = 1}) =>
      {
        'id': id,
        'owner': {'rid': device, 'rtype': 'device'},
        'renderer': true,
        'renderer_reference': {'rid': light, 'rtype': 'light'},
        'max_streams': streams,
      };
  Map<String, Object> scene(String id, String name, String group,
          {bool active = false}) =>
      {
        'id': id,
        'metadata': {'name': name},
        'group': {'rid': group, 'rtype': 'room'},
        'status': {'active': active ? 'static' : 'inactive'},
      };
  final bridge = BridgeController(
    store: InMemoryCredentialStore(
      HueCredentials(
        bridge: const HueBridgeInfo(id: '001788fffe123456', host: '10.0.0.9'),
        applicationKey: 'key',
        clientKey: 'A' * 32,
      ),
    ),
    clientFactory: (pin, key) => HueBridgeClient(
      host: pin.host,
      applicationKey: key,
      client: MockClient((request) async {
        if (request.method != 'GET') {
          return json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/light':
            return json({
              'data': [
                light('l1', 'd1', 'Sofa', x: 0.6, y: 0.33),
                light('l2', 'd2', 'Reading lamp', x: 0.2, y: 0.3),
                light('l3', 'd3', 'Floor lamp', x: 0.45, y: 0.45),
                light('l4', 'd4', 'TV strip', x: 0.17, y: 0.25),
                light('l5', 'd5', 'Kitchen', x: 0.44, y: 0.4, brightness: 90),
              ],
            });
          case '/clip/v2/resource/room':
            return json({
              'data': [
                {
                  'id': 'r1',
                  'metadata': {'name': 'Living room'},
                  'children': [
                    for (final d in ['d1', 'd2', 'd3', 'd4'])
                      {'rid': d, 'rtype': 'device'},
                  ],
                  'services': [
                    {'rid': 'g1', 'rtype': 'grouped_light'},
                  ],
                },
                {
                  'id': 'r2',
                  'metadata': {'name': 'Kitchen'},
                  'children': [
                    {'rid': 'd5', 'rtype': 'device'},
                  ],
                  'services': [
                    {'rid': 'g2', 'rtype': 'grouped_light'},
                  ],
                },
              ],
            });
          case '/clip/v2/resource/zone':
            return json({
              'data': [
                {
                  'id': 'z1',
                  'metadata': {'name': 'Downstairs'},
                  'children': [
                    for (final l in ['l1', 'l2', 'l3', 'l4', 'l5'])
                      {'rid': l, 'rtype': 'light'},
                  ],
                  'services': [
                    {'rid': 'g3', 'rtype': 'grouped_light'},
                  ],
                },
              ],
            });
          case '/clip/v2/resource/scene':
            return json({
              'data': [
                scene('s1', 'Movie night', 'r1', active: true),
                scene('s2', 'Relax', 'r1'),
                scene('s3', 'Bright', 'r1'),
                scene('s4', 'Cooking', 'r2'),
              ],
            });
          case '/clip/v2/resource/entertainment':
            return json({
              'data': [
                entertainment('e1', 'd1', 'l1'),
                entertainment('e2', 'd2', 'l2'),
                entertainment('e3', 'd3', 'l3'),
                entertainment('e4', 'd4', 'l4', streams: 3),
              ],
            });
          case '/clip/v2/resource/entertainment_configuration':
            return json({
              'data': [
                {
                  'id': '1a8d99cc-967b-44f2-9202-43f976c0fa6b',
                  'metadata': {'name': 'TV area'},
                  'configuration_type': 'screen',
                  'status': 'inactive',
                  'locations': {
                    'service_locations': [
                      for (final (id, x, y) in [
                        ('e1', 0.7, -0.6),
                        ('e2', -0.7, -0.5),
                        ('e3', -0.8, 0.5),
                        ('e4', 0.0, 0.9),
                      ])
                        {
                          'service': {'rid': id, 'rtype': 'entertainment'},
                          'positions': [
                            {'x': x, 'y': y, 'z': 0.0},
                          ],
                        },
                    ],
                  },
                  'channels': [
                    for (final (i, id, x, y) in [
                      (0, 'e1', 0.7, -0.6),
                      (1, 'e2', -0.7, -0.5),
                      (2, 'e3', -0.8, 0.5),
                      (3, 'e4', 0.0, 0.9),
                    ])
                      {
                        'channel_id': i,
                        'position': {'x': x, 'y': y, 'z': 0.0},
                        'members': [
                          {
                            'service': {'rid': id, 'rtype': 'entertainment'},
                          },
                        ],
                      },
                  ],
                },
              ],
            });
        }
        return json({'data': <Object>[]});
      }),
    ),
  );
  await tester.runAsync(bridge.initialize);
  return bridge;
}
