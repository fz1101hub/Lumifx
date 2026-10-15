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

## Content policy

Effects and visual assets should be original. Inspiration can come from broad themes and genres, but proprietary names, artwork, audio and authored sequences from third-party apps should not be copied.

### Localisation (`lib/l10n`)

Strings are ARB files (`app_en.arb` is the template, `app_it.arb` the
Italian translation) compiled by `flutter gen-l10n` on every `flutter pub
get` into `lib/l10n/generated/` (git-ignored, excluded from analysis and
formatting). Widgets read them through `context.l10n`
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
