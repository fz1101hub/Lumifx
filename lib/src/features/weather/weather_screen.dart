import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/weather/weather.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'weather_lights.dart';

/// The weather on the lights: the user types a city once, then sees the
/// weather now and tomorrow and puts either on the lamps.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _city = TextEditingController();
  List<WeatherPlace>? _results;
  var _searching = false;
  String? _searchError;
  var _choosing = false;
  Future<WeatherReport>? _report;
  WeatherPlace? _reportFor;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final query = _city.text.trim();
    if (query.length < 2) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await scope.weather.search(query, language: language);
      if (mounted) {
        setState(() {
          _results = results;
          _searchError = results.isEmpty ? l10n.weatherNoResults : null;
        });
      }
    } on Object catch (error) {
      debugPrint('Weather search: $error');
      if (mounted) {
        setState(() => _searchError = l10n.weatherFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _choose(WeatherPlace place) async {
    await AppScope.of(context).preferences.setWeatherPlace(place);
    if (mounted) {
      setState(() {
        _choosing = false;
        _results = null;
        _searchError = null;
        _report = null;
      });
    }
  }

  Future<void> _show(WeatherReading reading, String name) async {
    final playback = AppScope.of(context).playback;
    await playback.switchEffect(weatherEffect(reading, name: name));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.weather)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final place = preferences.weatherPlace;
          return ListView(
            padding: context.pageInsets(),
            children: [
              if (place == null || _choosing)
                ..._searchView(context)
              else
                ..._reportView(context, place),
              const SizedBox(height: 24),
              Text(
                l10n.weatherAttribution,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _searchView(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final results = _results;
    return [
      Text(l10n.weatherDescription, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _city,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          labelText: l10n.weatherCity,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: l10n.weatherSearch,
            icon: const Icon(Icons.search),
            onPressed: _searching ? null : _search,
          ),
        ),
      ),
      if (_searching)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_searchError case final error?)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ),
      if (results != null && !_searching)
        for (final place in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(place.name),
            subtitle: Text(place.label),
            onTap: () => _choose(place),
          ),
    ];
  }

  List<Widget> _reportView(BuildContext context, WeatherPlace place) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_report == null || _reportFor != place) {
      _reportFor = place;
      _report = AppScope.of(context).weather.forecast(place);
    }
    return [
      Row(
        children: [
          const Icon(Icons.place_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(place.label, style: theme.textTheme.titleMedium),
          ),
          TextButton(
            onPressed: () => setState(() {
              _choosing = true;
              _city.text = place.name;
            }),
            child: Text(l10n.weatherChange),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FutureBuilder<WeatherReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Text(l10n.weatherFailed, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _report = null),
                  child: Text(l10n.retry),
                ),
              ],
            );
          }
          final report = snapshot.data;
          if (report == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final tomorrow = report.tomorrow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadingCard(
                title: l10n.weatherNow,
                reading: report.now,
                onShow: () =>
                    _show(report.now, l10n.weatherNowName(place.name)),
              ),
              if (tomorrow != null)
                _ReadingCard(
                  title: l10n.weatherTomorrow,
                  reading: tomorrow,
                  onShow: () =>
                      _show(tomorrow, l10n.weatherTomorrowName(place.name)),
                ),
            ],
          );
        },
      ),
    ];
  }
}

/// The weather now or tomorrow, and a button to put it on the lights.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.title,
    required this.reading,
    required this.onShow,
  });

  final String title;
  final WeatherReading reading;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final low = reading.low;
    final temperature = low == null
        ? l10n.weatherTemperature(_degrees(reading.temperature))
        : l10n.weatherHighLow(_degrees(reading.temperature), _degrees(low));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(weatherIcon(reading), size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(weatherName(l10n, reading.kind),
                          style: theme.textTheme.titleLarge),
                      Text(temperature, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onShow,
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(l10n.weatherShow),
            ),
          ],
        ),
      ),
    );
  }

  /// Fahrenheit where people use it, Celsius elsewhere.
  static String _degrees(double celsius) {
    final fahrenheit =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode == 'US';
    return (fahrenheit ? celsius * 9 / 5 + 32 : celsius).round().toString();
  }
}

String weatherName(AppLocalizations l10n, WeatherKind kind) => switch (kind) {
      WeatherKind.clear => l10n.weatherClear,
      WeatherKind.partlyCloudy => l10n.weatherPartlyCloudy,
      WeatherKind.cloudy => l10n.weatherCloudy,
      WeatherKind.fog => l10n.weatherFog,
      WeatherKind.drizzle => l10n.weatherDrizzle,
      WeatherKind.rain => l10n.weatherRain,
      WeatherKind.snow => l10n.weatherSnow,
      WeatherKind.thunder => l10n.weatherThunder,
    };

IconData weatherIcon(WeatherReading reading) => switch (reading.kind) {
      WeatherKind.clear =>
        reading.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
      WeatherKind.partlyCloudy => Icons.wb_cloudy_outlined,
      WeatherKind.cloudy => Icons.cloud_outlined,
      WeatherKind.fog => Icons.foggy,
      WeatherKind.drizzle => Icons.grain,
      WeatherKind.rain => Icons.water_drop_outlined,
      WeatherKind.snow => Icons.ac_unit,
      WeatherKind.thunder => Icons.thunderstorm_outlined,
    };
