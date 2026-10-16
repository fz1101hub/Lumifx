import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/weather/weather.dart';

/// A touch of the temperature in the sunny scenes: icy blue when it
/// freezes, deep orange in a heat wave.
String temperatureAccent(double celsius) => switch (celsius) {
      <= 0 => '#9AD0FF',
      <= 10 => '#B9D7FF',
      <= 20 => '#FFE29A',
      <= 28 => '#FFB347',
      _ => '#FF7A3D',
    };

/// The weather of [reading] on the lights: sunshine, clouds, rain falling
/// from lamp to lamp, snowflakes, a far-off storm (slow glows, never
/// lightning), a starry night. Plays until stopped.
LightingEffect weatherEffect(WeatherReading reading, {required String name}) {
  final kind = reading.kind;
  final day = reading.isDay;
  final accent = temperatureAccent(reading.temperature);
  EffectEvent ambient(
    List<String> palette,
    double low,
    double high, {
    double speed = 0.02,
  }) =>
      EffectEvent(
        at: Duration.zero,
        duration: const Duration(minutes: 1),
        type: EffectEventTypes.ambientPalette,
        parameters: {
          'palette': palette,
          'brightnessMin': low,
          'brightnessMax': high,
          'speed': speed,
        },
      );
  EffectEvent drops(String color, int stepMs, double brightness) => EffectEvent(
        at: Duration.zero,
        duration: const Duration(minutes: 1),
        type: EffectEventTypes.travel,
        parameters: {
          'color': color,
          'pattern': 'random_walk',
          'stepDuration': stepMs,
          'brightness': brightness,
        },
      );
  List<EffectEvent> sparkles(String color, double brightness) => [
        for (var s = 4; s < 60; s += 7)
          EffectEvent(
            at: Duration(seconds: s),
            duration: const Duration(seconds: 3),
            type: EffectEventTypes.surprise,
            parameters: {
              'color': color,
              'count': 2,
              'brightness': brightness,
            },
          ),
      ];
  final events = switch (kind) {
    WeatherKind.clear when day => [
        ambient(['#FFD36B', '#FFF1B8', '#FFB347', accent], 0.6, 0.9),
      ],
    WeatherKind.clear => [
        ambient(const ['#0B1033', '#1C2A6B', '#2E3F8F'], 0.12, 0.3),
        ...sparkles('#FFFFFF', 0.6),
      ],
    WeatherKind.partlyCloudy when day => [
        ambient(['#FFE29A', '#CFE3F5', '#9EC5E8', accent], 0.5, 0.8,
            speed: 0.03),
      ],
    WeatherKind.partlyCloudy => [
        ambient(const ['#1C2A6B', '#4A5A7A', '#2E3F8F'], 0.15, 0.3),
        ...sparkles('#DDE6FF', 0.4),
      ],
    WeatherKind.cloudy => [
        ambient(const ['#B8C4D0', '#8E9AAF', '#CBD5E1'], 0.35, 0.6,
            speed: 0.015),
      ],
    WeatherKind.fog => [
        ambient(const ['#D5DCE3', '#AEB8C2'], 0.2, 0.35, speed: 0.008),
      ],
    WeatherKind.drizzle => [
        ambient(const ['#7FA7C9', '#A9C2D9', '#5B86AD'], 0.3, 0.55),
        drops('#CFE8FF', 900, 0.6),
      ],
    WeatherKind.rain => [
        ambient(const ['#2F5D8A', '#4A7DB0', '#1E3F66'], 0.3, 0.6),
        drops('#9FD3FF', 450, 0.8),
      ],
    WeatherKind.snow => [
        ambient(const ['#E8F4FF', '#CFE8FF', '#FFFFFF'], 0.45, 0.75,
            speed: 0.01),
        ...sparkles('#FFFFFF', 0.9),
      ],
    WeatherKind.thunder => [
        ambient(const ['#2A1B5C', '#3A2F7A', '#1B1035'], 0.15, 0.35),
        for (final s in const [12, 31, 47])
          EffectEvent(
            at: Duration(seconds: s),
            duration: const Duration(milliseconds: 1200),
            type: EffectEventTypes.magicFlash,
            parameters: const {
              'color': '#E8E0FF',
              'target': 'all',
              'brightness': 0.8,
            },
          ),
      ],
  };
  return LightingEffect(
    id: '${LightingEffect.generatedPrefix}weather:${kind.name}:'
        '${day ? 'day' : 'night'}:${reading.temperature.round()}',
    name: name,
    kind: EffectKind.scene,
    loopDuration: const Duration(minutes: 1),
    events: events,
  );
}
