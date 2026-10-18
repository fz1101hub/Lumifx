# LumiFX architecture

## Principles

LumiFX is cross-platform by default. Shared product behavior, effect definitions and most Hue integration logic live in Dart. Native Swift or Kotlin code is reserved for capabilities that genuinely require platform-specific APIs.

## Product layers

### UI

Flutter screens for onboarding, bridge setup, rooms, zones, effect discovery, playback, favorites and settings.

### Hue domain

A platform-independent domain layer will model bridges, rooms, zones, lights, capabilities and entertainment areas.

### Hue transport

The first implementation will target the local Hue API for discovery, pairing and normal light control. High-frequency effects will use a dedicated streaming transport when implemented.

### Effect engine

Effects are data-driven timelines rather than hard-coded screens.

Three top-level effect kinds are planned:

- **Scene**: continuous ambience.
- **Story**: narrative sequence with timed and randomized events.
- **Interactive**: effect responding to live triggers such as audio or user actions.

The engine should eventually support:

- palettes and gradients
- brightness envelopes
- per-light targeting
- spatial movement
- deterministic and seeded randomness
- looping sections
- surprise events
- audio cues
- interactive triggers

## Implementation notes

### Hue integration (`lib/src/core/hue`)

- **Discovery** combines native Bonjour/NSD (`_hue._tcp`, via the `nsd`
  plugin so iOS does not need the multicast entitlement) with the
  `discovery.meethue.com` endpoint. Manual IP entry is verified through the
  unauthenticated `/api/0/config`.
- **Pairing** polls `POST /api` with `generateclientkey: true` until the link
  button is pressed. The application key and the Entertainment client key
  are stored with `flutter_secure_storage`.
- **TLS**: the bridge certificate is not trusted by the OS. LumiFX accepts it
  only for the bridge's host, only if its CN is the bridge id, and pins its
  SHA-256 fingerprint at pairing time.
- **CLIP API v2** is used for lights, rooms, zones and `grouped_light`. Rooms
  list devices, so they are resolved to lights through each light's owner.

`fetchHome` also reads the `scene` resource, so Rooms & zones can recall
the scenes made in the Hue app (`PUT scene/{id}` with `recall: active`).

### Effect engine (`lib/src/core/effects/engine`)

- `EffectRenderer` turns a timeline into one `LightFrame` per slot as a pure
  function of `(effect, slotCount, seed, time)`. Slots are abstract, spatially
  ordered positions; the player maps them to the selected room's lights.
- `ambient_palette` events form a persistent background until the next
  ambient event starts. Other events (`magic_flash`, `travel`, `surprise`,
  `dim`, `lightning`, `beat`, `footsteps`, `music`) are overlays that are
  active only within their window. Any overlay can carry `chance` (0..1) to
  fire on only some passes.
- `music` events read live `AudioFeatures` passed to `render`; everything
  else stays a pure function of time.
- Effects flagged `prefersStreaming` change faster than the REST API can
  follow; the UI recommends an entertainment area for them.
- Randomness is reseeded on every pass of the timeline, so stories vary
  between loops while staying reproducible for a given seed.
- `EffectPlayer` advances effect time by wall time × speed and feeds a
  `LightOutput`. `RateLimitedLightOutput` keeps REST traffic within ~10
  commands per second, giving the budget to the lights whose state changed
  most, with transitions matching the time since their last update.
- Hue Entertainment streaming is just another `LightOutput`, so effects do
  not change when the transport does.

### Entertainment streaming (`lib/src/core/hue/entertainment`)

Fast effects (lightning, flashes, music) need more than the REST budget of
~10 commands per second. With an entertainment area (created in the Hue
app) LumiFX streams every channel at 50 messages per second:

1. `GET /auth/v1` returns the `hue-application-id`, used as PSK identity
   (falling back to the application key).
2. `PUT entertainment_configuration/{id}` with `action: start` reserves the
   area; only one app can stream to it at a time.
3. A DTLS 1.2 handshake on UDP 2100 with the `clientkey` from pairing as
   PSK and `TLS_PSK_WITH_AES_128_GCM_SHA256`.
4. HueStream v2 messages (xy + brightness, ≤ 20 channels each) are sent on
   every player tick (20 ms), and repeated twice a second while paused,
   because the bridge closes an idle stream after ~10 s.
5. Closing sends `close_notify` and `action: stop`.

The stream is one-way, so a bridge that drops it silently (another app took
the area, a reboot) would go unnoticed. `EntertainmentSession` therefore
polls the area's REST `status` every 5 s and ends the session (reported in
the player as "Streaming stopped by the bridge") when it is no longer
`active`; a lost UDP socket or a DTLS alert ends it at once.

Channels are ordered left to right (then front to back) from their
positions, so effects that move across slots move across the room.

**DTLS** is a small client written in Dart (`dtls/`), because Flutter has no
DTLS and OpenSSL is not available on iOS/Android. It deliberately supports
only what Hue needs: one PSK cipher suite, cookie exchange, retransmission,
fragment reassembly, AES-GCM records. The server is authenticated by its
Finished message, which requires the PSK. It is tested against
`openssl s_server` (`test/core/hue/dtls_interop_test.dart`,
`entertainment_test.dart`); CI runs those tests. If it ever proves
insufficient, the alternative is a native plugin (BouncyCastle on Android,
Network.framework on iOS) behind the same `EntertainmentSession`.

### Entertainment area editor (`lib/src/features/entertainment`)

Areas can be created without the Hue app: the editor lists lights whose
`entertainment` service is a renderer (at most 10 per area), lets the user
drag them on a top-view map (x left→right, y back→front, height
low/mid/high) and saves through `POST`/`PUT entertainment_configuration`
with `locations.service_locations`. Gradient lights get one position per
stream (`max_streams`), spread around the chosen point.

### Music Sync (`lib/src/core/audio`, `lib/src/features/music`)

- The microphone delivers 44.1 kHz mono 16-bit PCM (`record` plugin), with
  automatic gain and noise suppression off so dynamics survive.
- `AudioAnalyzer` runs a 1024-sample Hann-windowed FFT every 512 samples
  (~11.6 ms): RMS and bass (20-250 Hz), mid (250-2000 Hz), treble
  (2-8 kHz) energies, normalised by slowly decaying peaks (automatic gain)
  behind a noise gate.
- Beats are spectral-flux onsets (30 Hz-4 kHz, log magnitudes) above an
  adaptive threshold (`max(mean + 2.5σ, 1.5·mean)` over ~0.75 s), at least
  280 ms apart; tempo is 60 / median of the last 8 intervals.
- `MusicSyncController` keeps the latest features and ages the beat timing
  to the moment the player reads them. The microphone runs only while a
  Music Sync effect is playing; audio is never stored or sent. The audio
  session never silences other apps: no audio-focus request on Android
  (interruptions do not pause the capture), a `mixWithOthers`
  play-and-record session on iOS that resumes by itself after a call, and
  no Bluetooth routing (a Bluetooth speaker would otherwise drop to the
  hands-free profile). A stream that stalls decays to silence; one that
  ends is reported.
- Analysis is verified on synthetic kick tracks, noisy backgrounds, steady
  noise and pure tones (`test/core/audio`).
- `AudioInput` is the source abstraction: `MicrophoneAudioInput` (the
  `record` plugin) and, on Android 10+, `PhoneAudioInput`, which feeds the
  same analyser with the audio the phone itself plays through Android's
  playback capture. The native side (`PhoneAudioCapture.kt`,
  `PhoneAudioCaptureService.kt`) asks for the media-projection consent,
  runs a `mediaProjection` foreground service with a notification, reads
  an `AudioRecord` built on an `AudioPlaybackCaptureConfiguration` and
  streams 16-bit mono PCM over an event channel; apps that opt out of
  capture are silent to it. The user picks the source in Settings
  (`PreferencesController.musicSource`); `PlaybackController` falls back
  to the microphone where phone audio is unavailable and switches sources
  mid-effect when the preference changes. The Dart side is tested against
  a mocked channel (`test/core/audio/phone_audio_input_test.dart`); the
  native capture needs a real device (`docs/QA_CHECKLIST.md`).

### TV Sync (`lib/src/core/camera`, `lib/src/features/tv`)

- `PluginCameraInput` opens the back camera through the `camera` plugin at
  the low preset (YUV 4:2:0 on Android, BGRA on iOS) and samples a frame
  at most every 90 ms; frames arriving while one is being read are
  dropped.
- `sampleScreen` reads about 64 × 48 pixels of the middle 70 % of the
  picture, splits them into eight zones left to right as the user sees the
  TV (the sensor orientation and the device orientation give the
  clockwise quarter turns), averages each zone, raises its saturation a
  little and returns a colour at full value plus a brightness. Frames
  whose buffers are too short are skipped. Tested on synthetic YUV and
  BGRA frames in every rotation (`test/core/camera`).
- `TvSyncController` smooths the zones between frames and drops them when
  no frame arrived for 1.5 s, so the lights fall back to the effect's dim
  background instead of freezing. `PlaybackController` starts it like the
  microphone (on play and resume, stopped on pause, switch and stop) and
  stops TV Sync when the app goes to the background, where the camera
  closes. The renderer's `screen` event gives each light the average of
  its share of the zones. Nothing is recorded, stored or sent.

### Generated effects: timers, parties, games, weather

Some effects are made on the spot rather than taken from the catalogue.
Their ids start with `gen:` (`LightingEffect.isGenerated`), so they are
never kept as recently played, favourited or scheduled, and the ones that
play once (`isLooping: false`) are stopped by `PlaybackController` at
their end with a `finished` notice.

- `LightTimer` (`lib/src/features/timers`) builds a `countdown` event that
  turns the lamps from one colour to another one after the other.
- `Birthday` (`lib/src/features/fun/birthday.dart`) builds the candles
  (one spark per year, then a warm flicker for up to ten minutes) and the
  party (darkness, a flash, confetti, a rainbow). Name and age travel in
  the id, so `narrationOf` can greet the person. `BlowDetector` hears a
  blow on the microphone: RMS above 0.3 of full scale for 350 ms.
- `GamePlan` (`lib/src/features/fun/light_games.dart`) draws a game's
  phases from a seed (whole seconds, so the calls line up with the
  read-along lines) and turns each phase into ambient, flash, travel,
  surprise and countdown events. `GameScreen` shows the current phase by
  the player's position.
- `weatherEffect` (`lib/src/features/weather`) maps an Open-Meteo reading
  (WMO code, day or night, temperature) to a looping scene.
  `OpenMeteoWeather` (`lib/src/core/weather`) is the only client of a
  service outside the home besides Hue discovery; it sends only the
  typed city and the chosen coordinates.

More generated effects follow the same pattern: `PathStory` parts
(`lib/src/features/paths`: a part with a turn waits ten minutes on its
last background for the choice), `SimonGame.background` (the colours are
live flashes, see below), `BreathingPattern.effect` (the `ramp` event
glides brightness and colour, eased), `Pomodoro` (countdown and break
phases), `Advent.effect` and `Countdown.effect`. Each is parsed back
from its id by `narrationOf` so its words are read along and aloud.
`KidRoutine` (`lib/src/features/routines`) shows its steps with the
`progress` event (a still bar across the lights, `value` of them lit, one
after the other); its stars are day keys (`yyyy-mm-dd:routine`) in the
preferences, one set per child (see Child profiles below).
`MonsterHunt` (`lib/src/features/bedtime/monster_spray.dart`)
answers each spray with a live flash (below) and ends in a guardian
scene under the sleep timer, which fades it out and switches the lights
off. `Cinema` (`lib/src/features/cinema`) phases are non-looping ramps
and holds (the film holds four hours, the intermission twenty minutes),
so their end puts the lights back as they were. `routeForPlaying`
(`playing_route.dart`) parses each kind back from its id, so the
mini-player opens the feature's own screen.

`EffectPlayer.flashNow` (and `PlaybackController.flash`) overlays one
colour on every light at once, for a set time, over whatever the effect
renders: the memory game answers taps with it. With `at` (0 the first
slot, 1 the last, like the renderer's `position` target) it lights only
the slot nearest that place along the room: the light piano's keys and
the Halloween party's red eyes.

### Around the house (`lib/src/core/hue/hue_house*.dart`)

Routines the bridge runs by itself, created and read back by the
`HueHouseRoutines` extension (a part of `hue_bridge_client.dart`):

- Away mode: two older-API schedules per room (on, off) with the
  bridge's randomised times (`W127/T19:00:00A00:30:00`), rooms 15 minutes
  apart; tagged `lumifx:<token>:away-on|away-off` in the description.
  The off days move one day on for a window past midnight and one more
  when the stagger pushes the time past midnight again.
- Night path: two older-API rules on a `ZLLPresence` sensor, named
  `lumifx:<token>:path-on|path-off`: presence true + changed inside the
  night window switches the room on dim; presence false for N minutes
  (`ddx`) switches it off, with the window extended a little.
- Natural light: five scenes and a `smart_scene` (newer API) with week
  timeslots; the bridge does not say who made a smart scene, so LumiFX
  remembers the ids it created in the preferences.

Everything is removed together, and a refused part removes what was
already created.

### Kids mode (`lib/src/features/kids`)

`KidsModeScreen` is a route named `/kids` under a `PopScope` that cannot
pop; `PlaybackShell` hides the mini-player under it and `LinkHandler`
neither opens screens nor imports while `preferences.kidsLocked`. The
app reopens it at start while locked. Leaving takes a sum (11–19 plus
6–14) in `GrownUpGate`; `GrownUpGate.ask(context, title:)` puts the same
sum in front of grown-up actions elsewhere (the star shop), asked there
in neutral words ("To go on, type the result of a + b.") rather than
the kids mode ones.

### Voices (`lib/src/core/speech/voice_recordings.dart`)

`FileVoiceRecordings` keeps one AAC file per line of a user story under
the app support directory (`voices/<story>/<second>.m4a`), indexed at
start; `ReadAloud` plays a recorded line in place of the system voice,
and plays recordings even with Read aloud off.

### Speech and photos

- `ReadAloud` (`lib/src/features/effects/read_aloud.dart`) follows the
  app-wide `PlaybackController`: while an effect with words plays and the
  preference is on, it speaks each new line of `narrationOf` through a
  `Speaker` (`TtsSpeaker` wraps `flutter_tts`), and stops on pause or
  stop.
- `paletteFromImage` (`lib/src/core/color/photo_palette.dart`) decodes a
  photo at 64 px wide and groups its pixels into 24 hue bins plus whites;
  vivid pixels weigh more, dark and grey ones are ignored, close hues are
  merged and washed-out ones strengthened for the lights.

### Music box and light shows (`lib/src/core/sound/melody*.dart`, `lib/src/features/music_box`)

- A `Melody` is a list of `Note`s (a MIDI pitch, 0 for a rest, held for
  some beats) at a tempo, with an `Instrument`: a music box for the three
  lullabies, little bells for the three carols. The tunes
  (`melodies.dart`) are traditional, long in the public domain, written
  out note by note.
- `synthesizeMelody` renders the tune `times` times through: each note is
  a few sine partials (harmonic for the music box; inharmonic, ringing
  longer for the bells) with a 4 ms attack and an exponential decay,
  ringing a little past its length; the whole is then normalised.
  Nothing is recorded. `AudioplayersSoundPlayer` writes it once as a WAV
  in the temporary folder (`v1_melody_<id>_x<times>`), like the ambient
  sounds, and plays it once instead of in a loop.
- `melodyEffect` (`melody_lights.dart`) turns the same `timeline` into
  lights: a dim (lullaby) or festive red, green and gold (carol)
  `ambient_palette` and one `magic_flash` per note on the light at its
  pitch, through the renderer's `position` target (0 the first slot, 1
  the last), so low notes sit on one side of the room and high ones on
  the other. The id (`gen:melody:<id>:<times>`) is all `soundscapeOf`
  needs to find the tune, so sound and lights start, pause and stop
  together like any effect's sounds. It does not loop; "Then fade out the
  lights" calls `PlaybackController.switchOffAtEnd`, which fades the
  lights out and switches them off when the tune ends (as the sleep
  timer does). A tune always plays at its own pace: `effectiveSpeed`
  is 1 for an effect with a melody whatever the speed slider says, so
  the lights never run ahead of the music.
- The thunder and the piano's notes are cues on top of the soundscape:
  `SoundPlayer.stopCues` silences them (and any still being rendered)
  at stop, pause and when sounds are switched off, apart from `stop`,
  which a new soundscape calls too.
- Tested in `test/core/sound/melody_test.dart`.

### Story maker (`lib/src/features/tales`)

- A `Tale` is a `TaleHero` (six, each with a default name, a colour and
  a description), a `TalePlace` (five, each with a palette), a
  `TaleQuest` (five problems, each with its solution) and the name typed
  (at most 24 characters: it is read five times). "Surprise me" draws the
  three at random and keeps a typed name.
- The words are ARB strings with the name as a placeholder: intro,
  place, problem, solution and ending, at fixed seconds (0, 9, 19, 30
  and 42 of 56). The hero always comes as a name with a description after
  it ("Sam, a baby dragon who…"), and the ARB descriptions tell
  translators the lines must not depend on the hero's gender, so any
  name reads right in every language. Every sentence is written in the ARB
  files: there is no AI and no network.
- `Tale.effect` gives each line its lights: the hero's colour travelling
  in, the place's palette with an accent (fireflies, a sweep of stars, a
  rainbow of flashes), the adventure's own events (the star carried back
  to the sky, the rainbow's colours coming back lamp by lamp, footsteps
  to a golden chest…) and a warm `ramp` from 45 % down to 6 %. It does
  not loop.
- The id holds everything (`gen:tale:<hero>:<place>:<quest>:<name>`,
  the name URI-encoded), so `Tale.of` rebuilds the tale for
  `narrationOf` (read along, read aloud) and for the mini-player. Tested
  in `test/features/tale_test.dart`.

### Learning games (`lib/src/features/learn`)

- `CountingGame` draws a number of blinks from 1 to the current highest
  (3 at first, one more after three right answers in a row, up to 9;
  never the same number twice in a row) and a colour for each. The screen
  plays a dim background and blinks with `PlaybackController.flash` (600
  ms on, 450 ms dark) together with a lamp on screen; a right answer
  flashes gold and, with sounds on, the `Speaker` says the number in the
  app's language.
- `LearnColour` has eight colours, each a one-colour scene
  (`gen:colourword:<colour>`) and a word in each of the app's eight
  languages (`colourWords`, in code rather than in the ARB files, because
  the language learnt is not the app's). The `Speaker` says the word with
  that language's voice (`speechLanguage`), whatever the app's language.
  `ColourQuiz` picks a colour (never twice in a row) and three others, in
  any order. Speech follows the Sounds setting and uses the phone's own
  text-to-speech, as Read aloud does.
- The preferences keep Count the lights' best score (`countingBest`, the
  most right answers in one game) and the language chosen last in
  Colours in another language (`learnLanguage`).
- Tested in `test/features/learn_test.dart`.

### NFC stickers (`lib/src/core/nfc`, `android/.../NfcChannel.kt`)

- `NfcWriter` is the Dart side of the `com.lumifx/nfc` method channel
  (`isAvailable`, `isEnabled`, `write`, `cancel`, `openSettings`); on
  iOS `ChannelNfcWriter` answers "unavailable" without calling it.
- On Android, `write` puts the activity in NFC reader mode (NFC-A, B, F
  and V) and waits. On a tag it writes one NDEF message with a single URI
  record (`NdefRecord.createUri`): an NDEF tag is checked for being
  writable and big enough first, a blank `NdefFormatable` tag is
  formatted with the message, anything else is "not NDEF". The answer is
  the name of an `NfcWriteResult` (`written`, `readOnly`, `tooSmall`,
  `notNdef`, `unavailable`, `failed`, `cancelled`); a new write or
  `cancel` answers the waiting one with `cancelled` and leaves reader
  mode.
- Reading needs no code: the manifest's `NDEF_DISCOVERED` filter for the
  `lumifx` scheme opens `MainActivity` with the link when the unlocked
  phone touches the sticker, and `LinkHandler` takes it like any other
  link. Permission `android.permission.NFC`; `android.hardware.nfc` is
  not required, so phones without NFC still install the app. No plugin
  was added.
- On iPhone LumiFX does not use Core NFC (no entitlement): the screen
  explains the Shortcuts app's NFC personal automation, with a link
  copied from `readyLinks`, which now also offers Start bedtime
  (`lumifx://app/bedtime`).
- `test/core/nfc/nfc_writer_test.dart` covers the channel; the radio
  needs a device.

### Notification lights, Android (`lib/src/features/notifications`, `NotificationLights.kt`, `NotificationLightsService.kt`)

- The user's choices (`NotificationLightsSettings`: on or off, the room
  or zone, a rule `package → #RRGGBB` per app, quiet hours from 22:00 to
  07:00 by default) live in the preferences. The apps to choose from are
  the launcher activities (a `<queries>` entry for MAIN/LAUNCHER, no
  `QUERY_ALL_PACKAGES`).
- `NotificationLightsSync`, created by the app, listens to the
  preferences and the bridge and pushes `notificationConfig(...)` as JSON
  to the native store (`com.lumifx/notification_lights`, `configure`):
  the bridge's host and id, the certificate fingerprint pinned at
  pairing, the application key, the lights of the chosen room with
  whether each takes colour, each package's colour as CIE xy, and the
  quiet hours. It sends only when the JSON changes; it sends null (which
  clears the store) when the feature is off, has no apps or no bridge is
  paired, and keeps the last copy while a paired bridge is out of reach.
- `NotificationLightsStore` keeps the JSON in the app's private shared
  preferences, encrypted with AES-GCM under a key generated in the
  Android Keystore, since it holds the bridge key. A key lost with a
  restore reads as nothing until the app sends the config again.
- `NotificationLightsService` is a `NotificationListenerService`, bound
  by Android only once the user allows notification access. On each
  posted notification it reads the `packageName` and nothing else (never
  the title, text or extras), skips LumiFX itself, ongoing notifications,
  group summaries, apps without a rule and the quiet hours, and flashes
  at most once per 15 s per app. It stores nothing.
- `BridgeSignal.flash` PUTs to `/clip/v2/resource/light/<id>` for each
  light: `signaling` with `on_off_color` in the app's xy (`on_off` for
  white lights) for 3 s, or `alert: breathe` where the light refuses
  signalling. It talks to the bridge over HTTPS with its own trust
  manager, which accepts only a certificate whose CN is the bridge id and
  whose SHA-256 matches the pinned fingerprint (the rule of
  `BridgeCertificatePin` in Dart), and checks the host name. So the
  service flashes with LumiFX closed, without the Flutter engine. "Try
  it" runs the same flash with the stored config.
- iOS has no equivalent: no app may see other apps' notifications.
- The colour dots on the screen are named for screen readers in the
  app's language: `NotificationLightsSettings.colorNames` maps each
  colour offered to a `LearnColour`.
- `test/features/notification_lights_test.dart` covers the settings, the
  config and the sync; the service needs a device.

### Lock screen and background audio on iPhone (`lib/src/core/live_activity.dart`, `ios/Runner/AppDelegate.swift`, `ios/LumiFXWidget/PlayingLiveActivity.swift`)

- While an effect plays or is paused on a room or zone (not the preview)
  and "Keep playing with the screen off" is on, `_syncLiveActivity` in
  `app.dart` sends a `LiveActivityState` (effect name, room, playing or
  paused, up to four of the effect's colours as ARGB, the translated
  "Stop") over `com.lumifx/live_activity`, only when it changes, and
  ends it when playback stops.
- `LiveActivityBridge` in `AppDelegate.swift` (iOS 16.1+, ActivityKit)
  requests an `Activity<PlayingAttributes>` or updates the one shown
  (`ActivityContent` from 16.2), and answers false when Live Activities
  are switched off; `end` ends them at once. `NSSupportsLiveActivities`
  is set in `Info.plist`.
- The widget extension draws it: `PlayingLiveActivity` is an
  `ActivityConfiguration` for the lock screen and the Dynamic Island
  (expanded, compact and minimal). `PlayingAttributes` is declared in
  both targets and the two must stay alike. Stop is a link to
  `lumifx://app/stop`: it opens the app, which stops the effect and puts
  the lights back. The extension's `@main` is now the `LumiFXWidgets`
  bundle (the favourites widget plus, from 16.1, the Live Activity); see
  `docs/IOS_WIDGET.md`.
- iOS suspends an app soon after it leaves the screen unless it plays
  sound. `UIBackgroundModes` declares `audio`, and the sound player's
  session is now `playback` with `mixWithOthers` (it was `ambient`), so
  LumiFX's sounds are heard with the silent switch on and mix with other
  apps' audio. `_syncBackground` lets playback go on in the background on
  iOS only when the effect has ambient sounds or a tune, Sounds are on
  and the screen-off setting is on: the sound keeps the app, and with it
  the effect's output to the bridge, running while locked. Silent
  effects still stop when the app leaves the screen, and the Live
  Activity goes with them.
- `test/core/live_activity_test.dart` covers the channel and the app
  tests when it is shown; the lock screen needs a device.

### Links to screens (`lib/src/features/links/screen_links.dart`)

- `lumifx://app/go/<slug>` parses to a `ScreenLink` of an `AppScreen`
  (ritual, routines, star-shop, story-maker, lullabies, monster-spray,
  piano, games, cinema, timers, breathing, simon, counting, colour-words,
  colour-mixing, morse, hot-and-cold, halloween, nap, noise). `LinkHandler` pushes `screenOf(screen)` under
  the route name `/go/<slug>`, unless that route is on top already or
  kids mode is locked. The ready-made links (and so NFC stickers) offer
  the ritual and the routines.

### Secret messages in Morse (`lib/src/features/learn/morse*.dart`)

- `MorseMessage` folds the typed text with `foldForSearch` (lower case,
  accents removed), keeps the letters A–Z and digits of `morseCode` and
  skips anything else; at most 30 characters are typed.
- Timing is counted in units of 350 ms: a dot is one unit of light, a
  dash three, with one dark unit between the signals of a letter, three
  between letters and seven between words. The fastest it gets (dots)
  is under 1.5 flashes a second, so the effect needs no flashing
  warning.
- `effect` is a generated, non-looping effect
  (`gen:morse:<RRGGBB>:<text>`, the text URI-encoded) with a dim navy
  `ambient_palette`, a one-second lead, then one `magic_flash` on every
  light per signal in the chosen colour. `letterAt(position)` gives the
  letter being sent at the player's position, which the screen lights
  up with its code; `MorseMessage.of` parses the id back for the
  mini-player. Tested in `test/features/morse_test.dart`.

### Hot and cold (`lib/src/features/fun/hot_cold*.dart`)

- Eleven levels, 0 (freezing) to 10 (boiling), starting at 2. Each level
  is a looping one-colour scene (`gen:hotcold:<level>`) whose colour is
  interpolated along six stops from icy blue to fiery red, with
  brightness and speed rising with the heat; Warmer and Colder switch
  between them with `switchEffect`, so the lights cross-fade.
- `wordOf` puts the levels into five words (freezing, cold, warm, hot,
  boiling); the `Speaker` says the word in the app's language only when
  it changes and Sounds are on. Found it! plays
  `gen:hotcold:found` once: a bright four-colour palette with white
  confetti (`surprise`) for 8 s. Tested in
  `test/features/hot_cold_test.dart`.

- Guess mode: `MorseQuiz` draws a letter (never the same twice in a
  row) and three others; the lamps flash the letter as a one-letter
  `MorseMessage`, as often as asked, until the right one is tapped.

### Light piano (`lib/src/features/music_box/light_piano*.dart`)

- Recording keeps `(Duration, key)` pairs from a `Stopwatch` (at most
  400); play-back replays them with the same gaps through the same
  press path (sound and one-lamp flash), stopped by a generation
  counter when the screen closes or the mode changes.

- `pianoKeys` are the eight white keys from middle C (MIDI 60) to the
  next C (72), each with a rainbow colour. A press calls
  `PlaybackController.note` and `PlaybackController.flash` with `at`
  set to the key's place (`index / 7`) for 900 ms, over the dim
  `gen:piano` background, which starts with the first press.
- `SoundPlayer.note` is single-note playback: `AudioplayersSoundPlayer`
  synthesises one music-box note with `synthesizeMelody`, writes it once
  as a WAV (`v1_note_<instrument>_<midi>`) and plays it on up to four
  low-latency players (`PlayerMode.lowLatency`) taking turns, so quick
  notes ring on together. It stays silent when Sounds are off.
- Learn a song: `pianoKeyFor` folds a note to the key of the same pitch
  class (the high C only for notes from 72 up), and `pianoSongs` keeps
  Twinkle Twinkle and Frère Jacques first, then the lullabies and carols
  whose notes all have a key. `PianoLesson` lights the next key and
  moves on only on the right one. `pianoNoteName` names the keys do re
  mi (Italian, Spanish, Portuguese, French with Ré), ドレミ (Japanese)
  or by letter (H for B in German). Tested in
  `test/features/light_piano_test.dart` and
  `test/core/effects/effect_player_test.dart`.

### Steps of your own and kept tales

- Routine steps are `RoutineItem`s: the built-in `RoutineStep` enum and
  `CustomStep` (id, name, picture index, colour; up to 12, stored in
  `customSteps`). A routine's kept steps are keys: the enum name, or
  `custom:<id>`; removing a custom step drops its key from every routine.
- `Tale.toUserStory` turns a made-up story into a `UserStory` (the
  place's palette, calm motion, 60 s, one moment per line with its
  words), saved with `saveUserStory` like any story of the user's own.

### Child profiles and the star shop (`lib/src/features/routines/child*.dart`, `star_shop*.dart`)

- A `Child` is an id and a name (at most 30 characters); the preferences
  keep up to six (`children`) and the active one (`activeChild`). There
  are none until a grown-up adds one.
- Per-child data is keyed `childId|key`: the routine steps
  (`routineSteps`) and the stars (`yyyy-mm-dd:routine`). The first child
  has an empty id and keeps bare keys, so the stars and steps saved
  before profiles existed become theirs without a migration; the others
  get `c<microseconds>` (an id never contains `|`). Removing a child
  drops their keys and their spent stars. Up to 800 stars per possible
  child (4,800) are kept in all, the oldest dropped first.
- `starsSpent` counts what each child spent; the balance is the stars
  earned minus those. The rewards (at most 20; a name, one of eight
  pictures, a cost of 1–99) are the same for every child. Adding,
  buying and removing a reward each go through `GrownUpGate.ask`; a
  purchase spends the active child's stars and plays `gen:starshop`
  once, a gold palette with confetti for 6 s.
- The story maker offers the children's names as chips for the hero.
  Tested in `test/features/children_test.dart`.

### Bedtime ritual (`lib/src/features/bedtime/ritual*.dart`)

- `RitualSettings` (in the preferences as `ritual`) holds the steps kept,
  always in the ritual's order and at least one, the lullaby and the
  guardian light's minutes (15, 30 or 60, as for the monster spray).
- `BedtimeRitualScreen` runs the steps in turn and clears the sleep
  timer at each one (a guardian timer left by the monster spray would
  otherwise cut the story short). The routine and the monster spray are
  pushed as their own screens and the ritual moves on when their route
  pops. The story (`Tale.random` with the active child's name) and the
  lullaby (`melodyEffect`, once) do not loop: the screen listens to
  `PlaybackController.notices` and moves on at the `finished` notice for
  the effect it started. The guardian light is
  `MonsterHunt.guardian` under a sleep timer, which fades it out and
  switches the lights off. Next step skips to the following one. Tested
  in `test/features/ritual_test.dart`.

### Halloween party and motion events (`lib/src/features/fun/haunted_party*.dart`, `lib/src/core/hue/hue_buttons.dart`)

- `HueBridgeClient` reads the `data:` lines of the bridge's event stream
  (`/eventstream/clip/v2`) once, for both `buttonEvents()` and the new
  `motionEvents()`. `motionEventsOf` picks the `motion` resources, reads
  `motion_report.motion` (newer firmware) or `motion.motion`, and names
  the sensor by the last part of its `id_v1` (`/sensors/<id>`): the
  older-API id that `fetchMotionSensors` lists (`HueMotionSensor`, as
  for the night path).
- `HauntedPartyScreen` listens only while the party is started and the
  screen is open; when the stream fails or ends it listens again after
  5 s. Motion from the chosen sensor scares unless the last scare was
  less than 15 s ago (`HauntedParty.rest`); Scare now ignores the rest.
- A scare is a white flash (400 ms), a green one (1.6 s) and red eyes
  (1.2 s) on one random lamp through `flash(at:)`, with
  `PlaybackController.thunder()` on the phone (silent when Sounds are
  off). The room (`gen:haunted`) is a slow purple, green, midnight blue
  and ember palette at 8–22 % with a faint 900 ms green glint on a random
  light now and then: nothing flashes fast. Nothing is stored. Tested in
  `test/features/haunted_party_test.dart`.

### Quick Settings tiles, Android (`android/.../QuickTiles.kt`)

- `LinkTileService` is a `TileService` that opens a `lumifx://` link in
  `MainActivity` with `startActivityAndCollapse` (a `PendingIntent` on
  Android 14+, an `Intent` before); on a locked phone it waits for
  `unlockAndRun`. `StopTileService` opens `lumifx://app/stop` and
  `BedtimeTileService` `lumifx://app/bedtime`, which `LinkHandler` takes
  like any link (kids mode lets both through).
- The manifest declares both services exported, protected by
  `android.permission.BIND_QUICK_SETTINGS_TILE`, with the `QS_TILE`
  action, an icon (`ic_tile_stop`, `ic_tile_bedtime`) and a label
  (`tile_stop`, `tile_bedtime`) translated in `res/values-*/strings.xml`.
  The user adds them from the quick settings edit panel; the app asks for
  no permission and has no Dart side for them.

## Content policy

Effects and visual assets should be original. Inspiration can come from broad themes and genres, but proprietary names, artwork, audio and authored sequences from third-party apps should not be copied.

### Localisation (`lib/l10n`)

Strings are ARB files (`app_en.arb` is the template; Italian, German,
French, Spanish, Dutch, Brazilian Portuguese and Japanese translations sit
next to it) compiled by
`flutter gen-l10n` on every `flutter pub get` into `lib/l10n/generated/`
(git-ignored, excluded from analysis and formatting).
`test/l10n_completeness_test.dart` fails when a file misses a key or a
placeholder. Widgets read them through `context.l10n`
(`features/common/app_text.dart`).

Controllers never produce user-facing text, because they have no locale:

- `BridgeController.problem` is a `BridgeProblem` enum; `PlaybackController`
  emits typed `PlaybackNotice`s; `DtlsException` carries a `DtlsFailure`
  and the Hue layer throws typed exceptions (`BridgeBusyException`,
  `EntertainmentStoppedException`, ...). `app_text.dart` maps all of them
  to sentences, falling back to the bridge's own English message for errors
  the app does not know.
- Effect names, descriptions and collections stay in English in the
  catalog (they double as stable identifiers for tests) and are translated
  by the `EffectText` extension, keyed by effect id.
- Lamp labels in the preview are `SlotLabel`s (`PreviewLamp`,
  `UnnamedChannel`, `NamedSlot`) rendered by the UI.

Android 13+ per-app language settings read `res/xml/locales_config.xml`;
iOS lists the languages in `CFBundleLocalizations`.

### Kids mode games (`lib/src/features/kids/kids_mode.dart`)

- `KidsActivity` (piano, counting, colours, mixing) names the games kids
  mode may offer; `PreferencesController.kidsActivities` keeps the ones
  a grown-up ticked (null: all of them). They open under the route name
  `/kids/<activity>`, and `isKidsModeRoute` keeps the mini-player (and so
  the way to the player and the rest of the app) away from them as from
  kids mode itself.

### Colour mixing (`lib/src/features/learn/colour_mixing*.dart`)

- `paintMixes` lists what two paints make as on a palette (red + yellow
  = orange, yellow + blue = green, blue + red = purple, red + white =
  pink); `mixOf` reads it in either order. `ColourMix.effect` is a
  `gen:mix:<a>:<b>` scene looping over 12 s: an ambient palette of both
  paints, then a ramp up from dark in the mix and an ambient of the mix.
  `MixQuiz` never asks the same pair twice in a row.

### Nap light (`lib/src/features/bedtime/nap_light*.dart`)

- `NapLight.effect` is a one-shot `gen:nap:<minutes>` scene: a faint
  amber ambient for the rest, then a 20 s ramp to green and a green
  ambient for 20 minutes; at its end the player stops and the lamps go
  back. The screen reads the rest from the effect playing, so it shows
  the countdown again when opened from the mini-player.

### Noise light (`lib/src/features/fun/noise_light*.dart`)

- `NoiseWatch` keeps only the RMS loudness of each microphone buffer,
  as 0..1 between -60 and -10 dBFS, smoothed quick to rise and slow to
  settle. The zone (`NoiseZone`: calm, loud, too loud, by `NoiseLimit`)
  rises after 0.6 s of louder noise and falls after 2 s of calmer, so a
  clap or a breath changes nothing. Each zone is a `gen:noise:<zone>`
  ambient; the screen switches effects only when the zone changes
  (clearing any leftover sleep timer), and stops the microphone (and the
  lamps) when it closes, when LumiFX goes to the background, when the
  stream ends, or when something else takes the lamps. The mini-player
  hides while a noise effect plays.

### Timer tunes and festivals

- A light timer started with `tune: true` has the id
  `gen:timer:<timer>:tune`; `soundscapeOf` gives it Twinkle on the music
  box, enough times through to cover the countdown event.
- `festivalOf` (`lib/src/features/home/seasons.dart`) reads a table of
  Diwali, Hanukkah and Lunar New Year dates (to 2035) with a window
  around each; the home shows the festival's shelf above the season's,
  as both can fall together (Diwali in Halloween, Hanukkah at Christmas).

### Round 5 notes

- `PreferencesController` keeps `napMinutes`, `noiseLimit` (a
  `NoiseLimit` name) and `teethTune` (on unless switched off); the
  screens read them when nothing was chosen on them yet.
- `KidsActivity` also offers `simon` and `breathing`; the games row in
  kids mode scrolls sideways.
- `RitualStep.breathing` (between the monster spray and the story)
  plays `BreathingPattern.flowerCandle` for one minute, captioned with
  its calls; the finished notice moves the ritual on, as for the story
  and the lullaby. Saved rituals without it keep their own steps.
- `PianoEcho` (`light_piano.dart`) makes tunes of key indices moving by
  at most two keys, never one note three times running, from 3 to 12
  notes; the screen plays them with `_press(replay: true)` and ignores
  the keys until it has finished.

### Round 6 notes

- `RoutineScreen` gives the brush-teeth step a timer button: it plays
  `LightTimer.teeth` (tune per `teethTune`), pushes `TimerRunningScreen`,
  and ticks the step if the playback's finished notice came for that
  timer meanwhile; otherwise it shows the routine's progress again.
- The ritual's guardian step speaks `ritualGoodnightName` (the active
  child's name) when `readAloud` and sounds are on.
- `PreferencesController.pianoEchoBest` keeps the longest tune played
  back in Repeat after me.

### Round 7 notes

- `RoutineScreen._doWith` opens a helper screen for a step and ticks the
  step when an effect it counts finishes meanwhile (the playback's
  finished notice): the light timers for brushing teeth and tidying up,
  and the story maker for story time (any `Tale` effect).
- The light piano's Listen first plays the lesson's melody through
  `_press(replay: true)`, which never advances the lesson.

### Round 8 notes

- `_nowEntry` (home) picks the morning routine (6:00–10:00) or the
  bedtime ritual (18:30–22:00) from `AppScope.clock`; the widget tests
  give every app a fixed clock, so none depends on the time they run.
- `RoutineScreen._doWith` runs one helper at a time (`_helperOpen` hides
  the step buttons and makes tiles wait), opens the helper only when
  `before` says it is ready (a timer that did not start is not shown),
  and keeps a sleep timer aside meanwhile, putting it back afterwards.

