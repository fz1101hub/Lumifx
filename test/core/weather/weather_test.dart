import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/core/weather/weather.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/weather/weather_lights.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _milan = WeatherPlace(
  name: 'Milan',
  region: 'Lombardy',
  country: 'Italy',
  latitude: 45.46427,
  longitude: 9.18951,
);

void main() {
  group('Open-Meteo', () {
    test('searches places by name, in the app language', () async {
      final requests = <Uri>[];
      final weather = OpenMeteoWeather(
        client: MockClient((request) async {
          requests.add(request.url);
          return _json({
            'results': [
              {
                'name': 'Milano',
                'admin1': 'Lombardia',
                'country': 'Italia',
                'latitude': 45.46427,
                'longitude': 9.18951,
              },
              {'name': 'Broken', 'latitude': 'x'},
              {
                'name': 'Milano',
                'country': 'Stati Uniti',
                'latitude': 30.7,
                'longitude': -96.9,
              },
            ],
          });
        }),
      );
      final places = await weather.search(' Milano ', language: 'it');
      expect(places.map((p) => p.label),
          ['Milano, Lombardia, Italia', 'Milano, Stati Uniti']);
      final url = requests.single;
      expect(url.host, OpenMeteoWeather.geocodingHost);
      expect(url.queryParameters['name'], 'Milano');
      expect(url.queryParameters['language'], 'it');
    });

    test('a too short name searches nothing; no results is empty', () async {
      var calls = 0;
      final weather = OpenMeteoWeather(
        client: MockClient((_) async {
          calls++;
          return _json({'generationtime_ms': 0.5});
        }),
      );
      expect(await weather.search('M'), isEmpty);
      expect(calls, 0);
      expect(await weather.search('Nowhereville'), isEmpty);
      expect(calls, 1);
    });

    test('reads the weather now and tomorrow', () async {
      Uri? asked;
      final weather = OpenMeteoWeather(
        client: MockClient((request) async {
          asked = request.url;
          return _json({
            'current': {'temperature_2m': 21.4, 'weather_code': 0, 'is_day': 0},
            'daily': {
              'weather_code': [2, 63],
              'temperature_2m_max': [24.0, 18.2],
              'temperature_2m_min': [14.0, 11.6],
            },
          });
        }),
      );
      final report = await weather.forecast(_milan);
      expect(asked!.host, OpenMeteoWeather.forecastHost);
      expect(asked!.queryParameters['latitude'], '45.4643');
      expect(report.now.kind, WeatherKind.clear);
      expect(report.now.isDay, isFalse);
      expect(report.now.temperature, 21.4);
      expect(report.tomorrow!.kind, WeatherKind.rain);
      expect(report.tomorrow!.temperature, 18.2);
      expect(report.tomorrow!.low, 11.6);
    });

    test('a failing service or an odd answer says so', () async {
      for (final response in [
        _json({'error': true}, 500),
        _json({'current': 'nope'}),
        http.Response('not json', 200),
      ]) {
        final weather =
            OpenMeteoWeather(client: MockClient((_) async => response));
        await expectLater(
            weather.forecast(_milan), throwsA(isA<WeatherUnavailable>()));
      }
      final offline = OpenMeteoWeather(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
          offline.search('Milan'), throwsA(isA<WeatherUnavailable>()));
    });

    test('tomorrow is optional', () async {
      final weather = OpenMeteoWeather(
        client: MockClient((_) async => _json({
              'current': {'temperature_2m': 3, 'weather_code': 71, 'is_day': 1},
            })),
      );
      final report = await weather.forecast(_milan);
      expect(report.now.kind, WeatherKind.snow);
      expect(report.tomorrow, isNull);
    });
  });

  test('weather codes map to what the sky does', () {
    expect(WeatherKind.fromCode(0), WeatherKind.clear);
    expect(WeatherKind.fromCode(2), WeatherKind.partlyCloudy);
    expect(WeatherKind.fromCode(3), WeatherKind.cloudy);
    expect(WeatherKind.fromCode(48), WeatherKind.fog);
    expect(WeatherKind.fromCode(55), WeatherKind.drizzle);
    expect(WeatherKind.fromCode(65), WeatherKind.rain);
    expect(WeatherKind.fromCode(81), WeatherKind.rain);
    expect(WeatherKind.fromCode(75), WeatherKind.snow);
    expect(WeatherKind.fromCode(86), WeatherKind.snow);
    expect(WeatherKind.fromCode(96), WeatherKind.thunder);
    expect(WeatherKind.fromCode(42), WeatherKind.cloudy);
  });

  test('places are saved and read back; broken ones are dropped', () async {
    expect(WeatherPlace.fromJson(_milan.toJson()), _milan);
    expect(WeatherPlace.fromJson({'name': 'X', 'latitude': 99, 'longitude': 0}),
        isNull);
    expect(WeatherPlace.fromJson('Milan'), isNull);
    expect(
        const WeatherPlace(
                name: 'Monaco', region: 'Monaco', latitude: 1, longitude: 1)
            .label,
        'Monaco');

    final store = InMemoryKeyValueStore();
    await PreferencesController(store: store).setWeatherPlace(_milan);
    final again = PreferencesController(store: store);
    await again.load();
    expect(again.weatherPlace, _milan);
  });

  group('weather on the lights', () {
    test('every sky renders, loops, and never flashes fast', () {
      for (final kind in WeatherKind.values) {
        for (final isDay in [true, false]) {
          final effect = weatherEffect(
            WeatherReading(kind: kind, temperature: 15, isDay: isDay),
            name: 'Weather',
          );
          expect(effect.isGenerated, isTrue);
          expect(effect.isLooping, isTrue);
          expect(effect.hasRapidFlashes, isFalse);
          final renderer = EffectRenderer(effect, slotCount: 4, seed: 1);
          for (var s = 0; s < 120; s += 5) {
            for (final frame in renderer.render(Duration(seconds: s))) {
              expect(frame.brightness, inInclusiveRange(0, 1));
            }
          }
        }
      }
    });

    test('rain falls from lamp to lamp; storms glow slowly', () {
      final rain = weatherEffect(
          const WeatherReading(kind: WeatherKind.rain, temperature: 9),
          name: 'Rain');
      expect(rain.events.map((e) => e.type), contains(EffectEventTypes.travel));
      final storm = weatherEffect(
          const WeatherReading(kind: WeatherKind.thunder, temperature: 20),
          name: 'Storm');
      final glows = storm.events
          .where((e) => e.type == EffectEventTypes.magicFlash)
          .map((e) => e.at.inSeconds)
          .toList();
      expect(glows, hasLength(3));
      for (var i = 1; i < glows.length; i++) {
        expect(glows[i] - glows[i - 1], greaterThan(5));
      }
    });

    test('sunny scenes carry a hint of the temperature', () {
      expect(temperatureAccent(-4), '#9AD0FF');
      expect(temperatureAccent(33), '#FF7A3D');
      final hot = weatherEffect(
          const WeatherReading(kind: WeatherKind.clear, temperature: 33),
          name: 'Hot');
      expect(hot.events.first.parameters['palette'], contains('#FF7A3D'));
      expect(hot.id, contains('clear:day:33'));
    });
  });
}
