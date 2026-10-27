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
5. ✅ First set of animated scenes and narrative Stories (7 scenes, 23 stories
   including Halloween, Christmas and holiday collections, colour variants for scenes)
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
- **Bedtime**: one tap plays a calm story with its words, then the new
  Goodnight Glow, then the lights fade out and switch off.
- **Effects scheduled on the bridge**: an effect saved as a dynamic Hue
  scene and recalled by the bridge at set times (optionally switched off
  later), with the phone off.
- **Hue buttons**: a Hue switch or smart button plays an effect, stops it
  or starts bedtime while LumiFX runs (bridge event stream).
- **Voice**: Siri phrases in eight languages ("Play Fireplace in LumiFX",
  "Start bedtime in LumiFX", "Stop LumiFX") and Google Assistant App
  Actions ("Open Fireplace in LumiFX"), through `lumifx://` links.
- **What fits now**: from 6 to 10 in the morning the home starts with
  the morning routine, in the evening with the bedtime ritual.
- **Holiday stories** for New Year, Valentine's Day, Carnival and Easter,
  first on the home in their season (Carnival and Easter follow Easter's
  date each year); Diwali, Hanukkah and Lunar New Year have a shelf of
  their own in their days (dates from published calendars up to 2035).
- **Ok-to-wake light**: a dim amber glow at night that turns green when
  children may get up, stored on the bridge.
- **Light timers**: teeth, tidying up, homework, focus and cooking; the
  lights change colour as time passes and end with a little party; the
  teeth timer can play Twinkle Twinkle on the music box meanwhile.
- **Read aloud**: the phone's voice reads each line of a story (and the
  game calls) as the lights reach it, in the app's language.
- **Scene from a photo**: the scene editor takes the main colours of a
  photo, read on the phone.
- **Birthday party**: candles on the lamps, a wish, blow them out (a tap
  or blowing on the microphone) and the room bursts into colour.
- **Light games**: red light, green light; statues; colour hunt.
- **Weather lights**: the weather now or tomorrow in a typed city, from
  Open-Meteo, as sunshine, clouds, rain, snow or a starry night.
- **Choose-your-path stories**: at each turn two big buttons choose the
  way; every path has its own ending.
- **Light memory** (Simon): the lamps flash a growing sequence of colours
  to repeat.
- **Calm breathing**: lamps and a circle rise and fall with the breath
  (flower and candle for children, square, 4-7-8).
- **Pomodoro** among the light timers.
- **Advent calendar** of light (24 doors) and **How many sleeps?**
  countdowns to big days.
- **Kids mode**: big buttons for chosen gentle effects, locked behind a
  grown-up's sum, even after a restart; links, voice and Hue buttons
  start only those effects meanwhile. It can also offer the light piano,
  counting, colour words, colour mixing, light memory and calm breathing,
  as a grown-up chooses; nothing on them leads out of kids mode.
- **Your own voice**: record the lines of your stories; they play in time
  with the lights.
- **Around the house** (on the bridge, phone off): away mode with
  randomised times, a night path on a Hue motion sensor, and natural
  light that follows the day (a smart scene).
- **Morning and evening routines**: picture checklists with the steps a
  grown-up chooses; the lamps fill up step by step, then a party and a
  star, with a chart of the last seven days. "Brush your teeth" and
  "Tidy the toys" have their light timer, and story time opens the story
  maker; each ticks its step when the time is up or the story is told.
- **Lullabies on a music box**: Brahms's Lullaby, Twinkle Twinkle,
  Frère Jacques and Au clair de la lune, made on the phone; each note lights a lamp by its pitch
  (low on one side, high on the other); once, three or five times, then
  the lights can fade out.
- **Christmas light show**: Jingle Bells, Silent Night and We Wish You a
  Merry Christmas on little bells, the lamps in red, green and gold note
  by note.
- **Story maker**: a hero, a place, an adventure and a name (or
  "Surprise me") make a five-line bedtime story (heroes include a
  penguin and a turtle; places a jungle and a little island; adventures
  a lost teddy and the sleepy moon) with its own lights,
  read along and aloud, ending in a warm glow that fades. Put together
  on the phone from written lines (no AI, no network), worded so it
  never depends on the hero's gender; a story can be kept among My
  stories.
- **Learning games**: Count the lights (the lamps blink, tap how many;
  the numbers grow up to 9; the best score is kept) and Colours in
  another language (the room turns a colour and the phone says its name
  in any of the eight languages, then a quiz; the language chosen last
  comes back) and Colour mixing (pick two paints: the lamps glow in both,
  go dark as if stirred and shine in the colour they make, e.g. yellow +
  blue = green; then guess what two paints make).
- **Monster spray**: five funny monsters hide in a dim purple room; each
  spray flashes the lamps and chases one away; then a warm guardian
  light for 15, 30 or 60 minutes that fades out.
- **Cinema mode**: the lights dim slowly for the film (to a faint glow
  or to dark), rise for the intermission and come back at the end.
- **NFC stickers**: on Android LumiFX writes a `lumifx://` link (a
  favourite, a playlist, bedtime, stop) on a sticker, and touching it
  with the unlocked phone starts it; on iPhone the Shortcuts app's NFC
  automation opens the link. `lumifx://app/go/ritual` (and the routines,
  star shop, story maker, lullabies, monster spray, piano, games,
  cinema, timers, breathing, simon, counting, colour-words,
  colour-mixing, morse, hot-and-cold, halloween, nap, noise) opens a
  family screen, e.g. from a sticker by the bed.
- **Notification lights** (Android): chosen apps flash the lights of a
  room in their own colour when they post a notification, even with
  LumiFX closed; only the app's name is seen, never what it says; quiet
  hours at night.
- **Lock screen on iPhone** (iOS 16.1+): the effect playing, its room,
  colours and a Stop on the lock screen and in the Dynamic Island;
  effects with sounds or a tune keep playing with the iPhone locked.
- **Quick Settings tiles** (Android): "Stop effect" and "Bedtime", added
  from the quick settings edit panel; on a locked phone they act after
  unlocking.
- **Secret messages in Morse**: type up to 30 characters and the lamps
  flash the letters and digits slowly in Morse, in a chosen colour, with
  the letter being sent lit up on screen and the alphabet to decode it;
  or guess the letter the lamps flash, among four.
- **Hot and cold**: a grown-up taps Warmer or Colder while a child looks
  for something hidden; the room goes from icy blue to fiery red, the
  phone says how hot it is, and Found it! ends in confetti of light.
- **Light piano**: eight keys from middle C, each a music-box note made
  on the phone and a flash of its rainbow colour on one lamp along the
  room; "Learn a song" makes the next key glow (Hot Cross Buns, Mary Had
  a Little Lamb, Ode to Joy and more, easiest first; "Listen first"
  plays the song with its keys glowing), a tune played can
  be recorded and played back with its lights, and "Repeat after me"
  plays a short tune for the child to play back, one note longer each
  time, with the best tune to beat. Notes are named as children learn them (do re mi, ドレミ, or
  letters with H in German).
- **Steps of your own** in the routines ("feed the cat"), with a
  picture and a colour, alongside the built-in ones.
- **A profile for each child** (up to six): their own routine steps and
  stars (the stars earned before stay with the first child); the story
  maker offers their names for the hero.
- **Star shop**: a grown-up sets rewards with a picture and a cost in
  stars; the child spends the stars of their routines, a grown-up
  confirms and the lamps throw a gold party. Kept on the phone only.
- **Bedtime ritual** in one tap: the evening routine, the monster spray,
  a minute of calm breathing, a story made up for tonight with the child
  as hero, a lullaby and the guardian light, one after the other, with
  the steps a grown-up keeps; it ends with "Goodnight, Mia!", said aloud
  when stories are read aloud.
- **Halloween party**: a purple and green room; when someone walks past
  a Hue motion sensor (or a grown-up taps Scare now) the lamps flash,
  the phone thunders and red eyes glow on one lamp, with 15 s of rest
  between sensor scares and nothing that flashes fast.
- **Noise light**: the lamps stay green while the room is calm, turn
  amber when it gets loud and red when it is too loud (quiet, indoor
  voices or playtime); the microphone only measures loudness, while the
  screen is open, and nothing is recorded.
- **Nap light**: a daytime ok-to-wake; a faint amber glow for a rest of
  20 minutes to two hours, then the lamps slowly turn green and stay
  green for 20 minutes before going back to how they were.
- **Light clock**: for children who cannot read the time; the lamps stay
  green, turn yellow 5 to 15 minutes before a set time (leaving, a meal,
  bed), red for the last two minutes and glow red when it is time, and
  the voice says when to get ready.
- **Light reminders and night switch-off** (Around the house): a room
  takes a colour at set times on chosen days (recycling, medicine,
  plants), and every night the chosen rooms fade out in case a light was
  left on; both are the bridge's own schedules, with the phone off.
- **How do you feel?**: a child taps a feeling, the room takes its
  colour and the voice says it is okay; anger and worry cool down to a
  calm blue, with breathing, a gentle story or a rest offered.
- **Tonight's moon**: the real phase, worked out on the phone, drawn on
  screen and shown by the lamps, the lit part on its side of the room.
- **Interval training**: HIIT, tabata or stretching led by the lights
  (yellow, green, blue, slow pulses in the last three seconds) and
  called by the voice.
- **Words and lights in sync**: a flash, lightning or a key lands at
  once, read-aloud lines start a moment early to meet their light, and
  sounds are made ahead.
- **Goal!**: a big button (or lumifx://app/goal on an NFC sticker or a
  shortcut) bursts the room into a team's colours; eight teams or your
  own from up to three colours.
- **Tooth fairy**: a soft pink and violet glow at dawn in the child's
  room (kept on the bridge), her letter read aloud in the morning and a
  magic star.
- **Occasions**: candlelit dinner, game night, reading light, aperitivo
  and "guests in 10 minutes", which brightens slowly to a welcome.
- **Board game referee**: whose turn it is in their colour, a light die
  that blinks the number, and a turn timer that turns red.
- **Hide and seek**: the voice counts aloud as the lamps dim, then
  "Ready or not, here I come!" and a searchlight sweeps the room.
- **Light farm**: tap an animal and the room takes its colour as the
  voice makes its sound, or hear a sound and find who makes it.
- **Around the world in light**: four short stories of places (northern
  lights, cherry blossom, Sahara, Amazon), each with a fact read aloud.
- **My tune**: keep what was played on the light piano (up to ten tunes),
  play it back and share it with a link or QR code.
- **Sing and colour**: the pitch of the voice picks the colour of the
  lamps, holding a note makes it brighter; it listens only while the
  screen is open.
- **Weekly report**: for each child, the stars of the week day by day
  against last week, the routines finished and when bedtime started.

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

The app is in English, Italian, German, French, Spanish, Dutch, Brazilian
Portuguese and Japanese. Every
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
