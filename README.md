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
5. ✅ First set of animated scenes and narrative Stories (6 scenes, 19 stories
   including Halloween and Christmas collections, colour variants for scenes)
6. ✅ Favorites, recently played and playback defaults

Also done ahead of schedule:

- **Hue Entertainment streaming** (50 Hz over DTLS) for entertainment areas,
  used automatically when one is selected as the player target.
- **Entertainment area editor**: create, edit and delete areas in LumiFX,
  placing lights on a top-view map of the room.
- **Music Sync**: on-device beat and spectrum analysis of the microphone,
  driving four Interactive effects (Beat Pulse, Party Chase, Spectrum,
  Mood Glow).
- **Everyday use**: the scenes saved in the Hue app can be recalled from
  Rooms & zones; a sleep timer fades an effect out and switches the lights
  off; a one-time warning and a "soften flashes" mode for photosensitive
  users; lights can be left out of an effect per room; favourites as
  home-screen shortcuts; eight languages (English, Italian, German, French,
  Spanish, Dutch, Brazilian Portuguese, Japanese).
- **Continuous playback**: effects keep playing while you browse, with a
  mini-player on every screen; changing effect cross-fades the lights.
- **Playlists** of effects, in order or shuffled, each for 1 to 60 minutes.
- **Scenes of your own**: two to five colours and a motion, with a live
  preview.
- **Save as Hue scene**: what the lights show, stored on the bridge for the
  Hue app, switches and voice assistants.
- **lumifx:// links** for Siri Shortcuts, Android routines, Tasker and NFC
  tags (Settings › Shortcuts and automations).
- **Home-screen widget** of the favourites on Android; on iOS the widget is
  written and needs one Xcode step with your App Group
  ([docs/IOS_WIDGET.md](docs/IOS_WIDGET.md)).
- **Screen off on Android**: effects keep playing when the phone locks,
  with a notification to stop them (foreground service).
- **Hue scenes that keep moving**: ambient effects saved as dynamic Hue
  scenes drift through their colours without LumiFX.
- **Wake-up and bedtime routines** stored on the bridge (sunrise fade,
  dim at night), alongside those made in the Hue app.
- **Sharing**: scenes and playlists by link or QR code, also as a backup.
- **Gradient lightstrips**: effects move along the strip in rooms too.
- **Night light**: the effect as soft glows full screen, as a bedside lamp.
- **Seasonal stories** first on the home around Halloween and Christmas.
- **Accessibility**: screen-reader labels, Material tap-target and contrast
  guidelines checked by a test, and the phone's reduce-motion setting
  softens flashes. Welcome pages on the first launch.
- **iPad and tablets**: the home, the effect lists and the player use
  wider layouts (tiles, grids, two panes) from 720 logical pixels up;
  the other screens keep a reading width.
- **Music Sync from the phone's own audio** (Android 10+): Settings ›
  Music Sync source › This phone's audio follows what the phone plays
  through Android's playback capture, with the system consent dialog and
  a foreground-service notification; apps that protect their audio stay
  silent to it. Not yet verified on a real device.
- **Gentle start**: effects fade in from what the lights show.
- **Sounds** for stories and scenes (crackling fire, waves, rain and
  thunder that answers the lightning), generated on the phone.
- **Several rooms at once** from the player's "Play on" menu.
- **Search and filters** across every effect, in every language.
- **Wall panel** for a tablet on the wall: clock, rooms, favourites, dims
  by itself.
- **Read-along stories**: the words of each story appear in time with its
  lights, to read aloud together.
- **Story editor**: stories of your own with moments on a timeline (spark,
  spell, footsteps, darkness, lightning…) and words to read along;
  shareable by link.
- **TV Sync**: the phone's camera watches the TV and the lights take its
  colours left to right; frames are averaged on the phone and never
  stored or sent. Needs testing with a real TV.

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

The app is in English, Italian, German, French, Spanish and Dutch. Every
user-facing string lives in `lib/l10n/app_en.arb` (the template) and one
`app_<code>.arb` per language; the Dart classes are generated into
`lib/l10n/generated/` by `flutter pub get` and are not committed. To add a
language, copy `app_en.arb` to `app_<code>.arb`, translate the values and
list the code in `ios/Runner/Info.plist` and
`android/app/src/main/res/xml/locales_config.xml`; a test checks that every
file carries every key.

```text
lib/src/
├── core/
│   ├── audio/          FFT, beat/spectrum analysis, microphone input
│   ├── camera/         TV Sync: colours of a camera frame, zone by zone
│   ├── color/          LightColor and RGB → CIE xy conversion
│   ├── effects/        effect model, renderer, player, outputs
│   └── hue/            discovery, pairing, CLIP v2 client, TLS pinning,
│       └── entertainment/  DTLS client, HueStream encoding, streaming session
└── features/
    ├── bridge/         onboarding, credentials, connection state
    ├── effects/        catalog, effect list, player screen
    ├── entertainment/  entertainment area list and editor
    ├── home/           home with favorites and recently played
    ├── library/        favorites, recents and defaults (shared_preferences)
    ├── music/          Music Sync controller
    ├── rooms/          room and zone controls
    ├── settings/
    └── tv/             TV Sync: camera input and controller
```


## Project documentation

- [Product vision & working specification](docs/PRODUCT_VISION.md) — structured source of truth for the product, architecture, effects, roadmap and decisions discussed so far.
- [Chat history snapshot](docs/CHAT_HISTORY.md) — complete snapshot of the visible project conversation through the request to archive the discussion.
- [Architecture](docs/ARCHITECTURE.md) — engineering architecture.
- [Release guide](docs/RELEASE.md) — signing, building and uploading to Google Play and the App Store.
- [Store listing](docs/STORE_LISTING.md) — texts, data-safety and privacy answers, review notes.
- [QA checklist](docs/QA_CHECKLIST.md) — what to verify on a real phone with a real bridge.
- [Privacy policy](docs/PRIVACY_POLICY.md) — published at <https://fz1101hub.github.io/Lumifx/privacy.html> together with the [support page](https://fz1101hub.github.io/Lumifx/) (source in `site/`).
