import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/notification_lights_platform.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/notifications/notification_lights.dart';
import 'package:lumifx/src/features/notifications/notification_lights_sync.dart';

class _FakePlatform implements NotificationLightsPlatform {
  final configured = <Map<String, Object?>?>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<List<InstalledApp>> apps() async => const [];

  @override
  Future<void> configure(Map<String, Object?>? config) async =>
      configured.add(config);

  @override
  Future<bool> test(Map<String, double> xy) async => true;
}

const _whatsapp = NotificationRule(
    package: 'com.whatsapp', label: 'WhatsApp', color: '#25D366');

const _credentials = HueCredentials(
  bridge: HueBridgeInfo(id: 'ecb5fafffe000001', host: '10.0.0.2'),
  applicationKey: 'key',
  certificateFingerprint: 'ab12',
);

const _home = HueHome(
  lights: {
    'c': HueLight(
        id: 'c', name: 'Lamp', deviceId: 'd1', isOn: true, supportsColor: true),
    'w': HueLight(id: 'w', name: 'Spot', deviceId: 'd2', isOn: true),
    'k': HueLight(id: 'k', name: 'Kitchen', deviceId: 'd3', isOn: true),
  },
  rooms: [
    HueGroup(
        id: 'living',
        name: 'Living room',
        kind: HueGroupKind.room,
        lightIds: ['c', 'w']),
    HueGroup(
        id: 'kitchen',
        name: 'Kitchen',
        kind: HueGroupKind.room,
        lightIds: ['k']),
  ],
  zones: [],
);

void main() {
  test('the settings survive a round trip and drop what is broken', () {
    final settings = const NotificationLightsSettings(
      enabled: true,
      target: 'kitchen',
      quiet: false,
      quietFrom: 23 * 60,
      quietTo: 6 * 60 + 30,
    ).withRule(_whatsapp);
    final back = NotificationLightsSettings.fromJson(settings.toJson());
    expect(back.enabled, isTrue);
    expect(back.target, 'kitchen');
    expect(back.quiet, isFalse);
    expect((back.quietFrom, back.quietTo), (23 * 60, 6 * 60 + 30));
    expect(back.rules.single.package, 'com.whatsapp');

    final broken = NotificationLightsSettings.fromJson({
      'rules': [
        {'package': 'a', 'label': 'A', 'color': 'red'},
        {'package': '', 'label': 'B', 'color': '#FF0000'},
        {'package': 'c', 'label': 'C', 'color': '#FF0000'},
      ],
      'quietFrom': 99999,
    });
    expect([for (final r in broken.rules) r.package], ['c']);
    expect(broken.quietFrom, 22 * 60);
    expect(NotificationLightsSettings.fromJson(null).enabled, isFalse);
  });

  test('an app has one colour; removing it leaves the others', () {
    var settings = const NotificationLightsSettings()
        .withRule(_whatsapp)
        .withRule(const NotificationRule(
            package: 'com.ring', label: 'Ring', color: '#FFD60A'))
        .withRule(_whatsapp.withColor('#0A84FF'));
    expect(settings.rules, hasLength(2));
    expect(settings.rules.first.color, '#0A84FF');
    settings = settings.withoutRule('com.whatsapp');
    expect([for (final r in settings.rules) r.package], ['com.ring']);
  });

  test('the service gets the bridge, the lights and the colours', () {
    final settings =
        const NotificationLightsSettings(enabled: true).withRule(_whatsapp);
    final config = notificationConfig(settings, _credentials, _home)!;
    expect(config['host'], '10.0.0.2');
    expect(config['bridgeId'], 'ecb5fafffe000001');
    expect(config['fingerprint'], 'ab12');
    expect(config['key'], 'key');
    // The first room unless another is chosen.
    expect(config['lights'], [
      {'id': 'c', 'color': true},
      {'id': 'w', 'color': false},
    ]);
    final xy = (config['rules']! as Map)['com.whatsapp']! as Map;
    expect(xy['x'], inExclusiveRange(0.1, 0.4));
    expect(xy['y'], inExclusiveRange(0.4, 0.8));
    expect(config['quiet'], {'from': 22 * 60, 'to': 7 * 60});

    final kitchen = notificationConfig(
        settings.copyWith(target: 'kitchen', quiet: false),
        _credentials,
        _home)!;
    expect(kitchen['lights'], [
      {'id': 'k', 'color': false},
    ]);
    expect(kitchen['quiet'], isNull);
  });

  test('nothing to flash, nothing for the service', () {
    final settings =
        const NotificationLightsSettings(enabled: true).withRule(_whatsapp);
    expect(
        notificationConfig(
            settings.copyWith(enabled: false), _credentials, _home),
        isNull);
    expect(
        notificationConfig(const NotificationLightsSettings(enabled: true),
            _credentials, _home),
        isNull);
    expect(notificationConfig(settings, null, _home), isNull);
    expect(notificationConfig(settings, _credentials, null), isNull);
    // No pinned certificate: the service could not trust the bridge.
    expect(
        notificationConfig(
            settings,
            const HueCredentials(
                bridge: HueBridgeInfo(id: 'b', host: 'h'), applicationKey: 'k'),
            _home),
        isNull);
  });

  test('the service is told once, and again only when something changes',
      () async {
    final platform = _FakePlatform();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.load();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await bridge.initialize();
    final sync = NotificationLightsSync(
        platform: platform, preferences: preferences, bridge: bridge);
    expect(platform.configured, [null]);
    // Not paired: still nothing to flash.
    await preferences.setNotificationLights(
        const NotificationLightsSettings(enabled: true).withRule(_whatsapp));
    expect(platform.configured, [null]);
    sync.dispose();
  });

  test('switched off while the bridge is away, the service stops anyway',
      () async {
    final platform = _FakePlatform();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.load();
    await preferences.setNotificationLights(
        const NotificationLightsSettings(enabled: true).withRule(_whatsapp));
    // Paired, but the bridge does not answer: no home yet.
    final bridge = BridgeController(
      store: InMemoryCredentialStore(_credentials),
      clientFactory: (pin, key) => HueBridgeClient(
        host: pin.host,
        client: MockClient((_) async => throw http.ClientException('away')),
        applicationKey: key,
      ),
    );
    await bridge.initialize();
    expect(bridge.home, isNull);
    final sync = NotificationLightsSync(
        platform: platform, preferences: preferences, bridge: bridge);
    expect(platform.configured, isEmpty,
        reason: 'the service keeps its lights while the bridge is away');

    await preferences.setNotificationLights(
        preferences.notificationLights.copyWith(enabled: false));
    expect(platform.configured, [null]);
    sync.dispose();
  });
}
