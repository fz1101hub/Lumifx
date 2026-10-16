import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A place to show the weather of, chosen by the user from a search.
class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
    this.country = '',
  });

  final String name;
  final String region;
  final String country;
  final double latitude;
  final double longitude;

  /// "Milan, Lombardy, Italy", skipping what is missing or repeated.
  String get label => {
        name,
        if (region.isNotEmpty) region,
        if (country.isNotEmpty) country,
      }.join(', ');

  Map<String, Object?> toJson() => {
        'name': name,
        'region': region,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Null when [json] is not a usable place.
  static WeatherPlace? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 120 ||
        latitude is! num ||
        longitude is! num ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    String text(Object? value) =>
        value is String && value.length <= 120 ? value : '';
    return WeatherPlace(
      name: name.trim(),
      region: text(json['region']),
      country: text(json['country']),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeatherPlace &&
      other.name == name &&
      other.region == region &&
      other.country == country &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, region, country, latitude, longitude);
}

/// What the sky does, from the WMO weather codes.
enum WeatherKind {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunder;

  static WeatherKind fromCode(int code) => switch (code) {
        0 => clear,
        1 || 2 => partlyCloudy,
        3 => cloudy,
        45 || 48 => fog,
        >= 51 && <= 57 => drizzle,
        >= 61 && <= 67 || >= 80 && <= 82 => rain,
        >= 71 && <= 77 || 85 || 86 => snow,
        >= 95 && <= 99 => thunder,
        _ => cloudy,
      };
}

/// The weather now, or of a whole day.
class WeatherReading {
  const WeatherReading({
    required this.kind,
    required this.temperature,
    this.isDay = true,
    this.low,
  });

  final WeatherKind kind;

  /// Degrees Celsius: now, or the day's highest.
  final double temperature;

  /// The day's lowest, for a forecast.
  final double? low;
  final bool isDay;
}

class WeatherReport {
  const WeatherReport({required this.now, this.tomorrow});

  final WeatherReading now;
  final WeatherReading? tomorrow;
}

/// The weather could not be fetched: offline, or the service failed.
class WeatherUnavailable implements Exception {
  const WeatherUnavailable(this.reason);

  final Object reason;

  @override
  String toString() => 'WeatherUnavailable: $reason';
}

abstract interface class WeatherService {
  /// Places matching [name], best first, named in [language].
  Future<List<WeatherPlace>> search(String name, {String language = 'en'});

  /// The weather now and tomorrow at [place].
  Future<WeatherReport> forecast(WeatherPlace place);
}

/// For tests and platforms without the network.
class NoWeatherService implements WeatherService {
  const NoWeatherService();

  @override
  Future<List<WeatherPlace>> search(String name, {String language = 'en'}) =>
      Future.error(const WeatherUnavailable('no weather service'));

  @override
  Future<WeatherReport> forecast(WeatherPlace place) =>
      Future.error(const WeatherUnavailable('no weather service'));
}

/// Open-Meteo (open-meteo.com): free, no key, no account. Only the name
/// typed in a search and the chosen place's coordinates are sent.
class OpenMeteoWeather implements WeatherService {
  OpenMeteoWeather({http.Client? client}) : _client = client;

  static const geocodingHost = 'geocoding-api.open-meteo.com';
  static const forecastHost = 'api.open-meteo.com';
  static const _timeout = Duration(seconds: 10);

  final http.Client? _client;

  Future<Object?> _get(Uri uri) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw WeatherUnavailable('HTTP ${response.statusCode}');
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on WeatherUnavailable {
      rethrow;
    } on Object catch (error) {
      throw WeatherUnavailable(error);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  @override
  Future<List<WeatherPlace>> search(
    String name, {
    String language = 'en',
  }) async {
    final query = name.trim();
    if (query.length < 2) {
      return const [];
    }
    final body = await _get(Uri.https(geocodingHost, '/v1/search', {
      'name': query,
      'count': '8',
      'language': language,
      'format': 'json',
    }));
    final results = body is Map ? body['results'] : null;
    return [
      if (results is List)
        for (final result in results)
          if (result is Map)
            if (WeatherPlace.fromJson({
              'name': result['name'],
              'region': result['admin1'],
              'country': result['country'],
              'latitude': result['latitude'],
              'longitude': result['longitude'],
            })
                case final place?)
              place,
    ];
  }

  @override
  Future<WeatherReport> forecast(WeatherPlace place) async {
    final body = await _get(Uri.https(forecastHost, '/v1/forecast', {
      'latitude': place.latitude.toStringAsFixed(4),
      'longitude': place.longitude.toStringAsFixed(4),
      'current': 'temperature_2m,weather_code,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'forecast_days': '2',
      'timezone': 'auto',
    }));
    try {
      final json = body! as Map;
      final current = json['current'] as Map;
      final now = WeatherReading(
        kind: WeatherKind.fromCode((current['weather_code'] as num).toInt()),
        temperature: (current['temperature_2m'] as num).toDouble(),
        isDay: current['is_day'] != 0,
      );
      WeatherReading? tomorrow;
      final daily = json['daily'];
      if (daily is Map) {
        final codes = daily['weather_code'];
        final highs = daily['temperature_2m_max'];
        final lows = daily['temperature_2m_min'];
        if (codes is List &&
            highs is List &&
            lows is List &&
            codes.length > 1 &&
            highs.length > 1 &&
            lows.length > 1 &&
            codes[1] is num &&
            highs[1] is num &&
            lows[1] is num) {
          tomorrow = WeatherReading(
            kind: WeatherKind.fromCode((codes[1] as num).toInt()),
            temperature: (highs[1] as num).toDouble(),
            low: (lows[1] as num).toDouble(),
          );
        }
      }
      return WeatherReport(now: now, tomorrow: tomorrow);
    } on Object catch (error) {
      throw WeatherUnavailable(error);
    }
  }
}
