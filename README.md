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

1. ✅ Discover and pair with a Hue Bridge
2. ✅ Read rooms, zones and lights
3. ✅ Basic light controls (room/zone on/off and brightness)
4. ✅ Shared effect engine (renderer, player, rate-limited Hue output)
5. ✅ First set of animated scenes and narrative Stories (6 scenes, 4 stories)
6. ✅ Favorites, recently played and playback defaults

Also done ahead of schedule: **Hue Entertainment streaming** (50 Hz over
DTLS) for entertainment areas, used automatically when one is selected as
the player target.

## Development

Requires Flutter (stable, see `.github/workflows/ci.yml` for the pinned version).

```sh
flutter pub get
flutter analyze
flutter test
flutter run            # on a device or simulator on the same Wi-Fi as the bridge
```

Effects can be previewed without a bridge: the player shows virtual lamps
when no room or zone is selected.

```text
lib/src/
├── core/
│   ├── color/          LightColor and RGB → CIE xy conversion
│   ├── effects/        effect model, renderer, player, outputs
│   └── hue/            discovery, pairing, CLIP v2 client, TLS pinning,
│       └── entertainment/  DTLS client, HueStream encoding, streaming session
└── features/
    ├── bridge/         onboarding, credentials, connection state
    ├── effects/        catalog, effect list, player screen
    ├── home/           home with favorites and recently played
    ├── library/        favorites, recents and defaults (shared_preferences)
    ├── rooms/          room and zone controls
    └── settings/
```


## Project documentation

- [Product vision & working specification](docs/PRODUCT_VISION.md) — structured source of truth for the product, architecture, effects, roadmap and decisions discussed so far.
- [Chat history snapshot](docs/CHAT_HISTORY.md) — complete snapshot of the visible project conversation through the request to archive the discussion.
- [Architecture](docs/ARCHITECTURE.md) — initial engineering architecture.
