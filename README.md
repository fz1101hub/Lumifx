# LumiFX

Cross-platform Philips Hue experience app for iOS and Android.

## Product direction

LumiFX is designed around three kinds of lighting experiences:

- **Scenes** — continuous ambience such as sunset, ocean, fireplace, aurora.
- **Stories** — narrative lighting sequences with surprises, movement and timed events.
- **Interactive** — experiences that can react to user input, audio or other triggers.

The project is intentionally built around an original effects engine and original content rather than reproducing proprietary assets or effects from other apps.

## Target platforms

- iOS
- Android

## Planned stack

- Flutter / Dart for the shared application
- Philips Hue local API for bridge, rooms, zones and lights
- Hue Entertainment streaming for high-frequency effects where appropriate
- Native Swift/Kotlin integrations only where platform-specific capabilities require them

## First milestone

1. Discover and pair with a Hue Bridge
2. Read rooms, zones and lights
3. Basic light controls
4. Shared effect engine
5. First set of animated scenes and narrative Stories
6. Favorites and local settings
