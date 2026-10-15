# LumiFX — Product Vision & Working Specification

This document is the structured source of truth for the product decisions made in the project conversation so far. The full visible conversation snapshot is preserved separately in [CHAT_HISTORY.md](./CHAT_HISTORY.md).

## 1. Product idea

LumiFX is a cross-platform lighting experience app for Philips Hue, inspired by the broad category of apps such as OnSwitch while remaining original in branding, UI, effect design, artwork, audio and authored sequences.

The product should go beyond basic smart-light controls. Its primary value is a rich catalogue of dynamic, cinematic and narrative lighting experiences that make a room feel as though something is happening inside it.

The intended experience combines:

- Philips Hue bridge, room, zone and light control
- animated scenes
- themed effects
- narrative effects
- interactive effects
- optional audio-reactive effects
- favorites
- timers and sleep/wake experiences
- future effect editing/customization

## 2. Platforms and technology direction

The app must be available on:

- iOS
- Android

The current preferred architecture is:

- **Flutter + Dart** for the shared product, UI, navigation, state, effect definitions and most business logic
- **Swift** only when iOS-specific capabilities require native code
- **Kotlin** only when Android-specific capabilities require native code

The reason for the cross-platform approach is to avoid maintaining two independent applications and to keep the iOS and Android experiences aligned.

## 3. Philips Hue integration

### 3.1 Local-first

Core operation should happen locally against the Philips Hue Bridge where possible.

Benefits discussed:

- lower latency
- less infrastructure
- no mandatory LumiFX account
- reduced personal-data handling
- works naturally with the Hue Bridge on the local network

A future version may add remote access through the Hue remote/OAuth flow, but remote control is not required for the initial product.

### 3.2 APIs

Normal control should use the Philips Hue API v2 over HTTPS/TLS for concepts such as:

- bridge
- rooms
- zones
- lights
- scenes
- brightness
- power
- color
- color temperature
- system state

High-frequency effects should use Hue's Entertainment/streaming capabilities instead of repeatedly sending REST updates.

Examples where streaming is expected to matter:

- music sync
- disco
- beat-reactive lighting
- lightning
- rapid cinematic sequences
- high-speed spatial movement across lamps

### 3.3 Bridge onboarding

The target onboarding flow is:

1. launch LumiFX
2. discover a Hue Bridge on the local network
3. ask the user to press the physical Hue Bridge button when required
4. pair the app
5. read rooms, zones and lights
6. arrive at the main experience browser
7. select an effect
8. see the real Hue lights respond

Discovery may involve local-network mechanisms such as mDNS/discovery supported by the platform and Hue ecosystem.

### 3.4 Platform permissions

iOS must correctly handle local-network permissions because LumiFX needs to discover and communicate with the Hue Bridge.

Android must also account for current and future local-network permission requirements.

Microphone permissions should only be requested when/if the user enables audio-reactive experiences.

## 4. Core product taxonomy

The app should make a strong distinction between three types of experiences.

### 4.1 Scenes

Continuous atmospheres that can run for a long time without a narrative arc.

Examples:

- Sunset
- Ocean
- Fireplace
- Aurora
- Relax
- Nature ambience
- Party ambience

Typical controls:

- play/pause
- brightness
- intensity
- speed
- palette
- selected rooms/lights

### 4.2 Stories

Narrative effects made from sequences, surprises and spatial movement.

The goal is to make the user feel that a creature, event or story is unfolding around the room.

Examples discussed:

- **Folletto nel bosco**
- **Tesoro nascosto**
- **Fata incantata**
- **Fantasma dispettoso**
- **Goblin nella miniera**
- **Drago addormentato**
- **Casa stregata**
- **Elfi di Natale**
- pirate-themed stories
- dinosaur stories
- supernatural stories
- underwater stories
- space adventures

The user's favorite reference point is the Irish leprechaun-style effect in OnSwitch. LumiFX should contain **more effects of that general imaginative/narrative kind**, but should not copy OnSwitch's proprietary authored effect, assets, names or audio.

The first original coded story in the repository is currently called **Emerald Trickster**.

### 4.3 Interactive

Effects that respond to something happening now.

Potential inputs:

- user taps
- microphone/audio
- beat
- volume
- frequency bands
- movement
- selected room/zone
- future sensor inputs

Examples discussed:

#### Caccia al tesoro

The user taps a "Cerca" action and one of the lamps becomes golden, creating a simple room-scale treasure-hunt interaction.

#### Mostro in casa

A creature can appear to move from one Hue zone to another through coordinated lighting changes.

## 5. Effect engine

The Effect Engine is one of the most important architectural components.

It should be **independent of specific physical lamps**. An effect defines desired behavior, while a separate mapping/playback layer decides how to project that behavior onto 2, 4, 8, 20 or more lights.

This makes the effect catalogue scalable and prevents each effect from requiring custom imperative code.

### 5.1 Data-driven effect definition

A continuous scene can be expressed using parameters such as:

- palette
- transition duration
- brightness min/max
- speed
- randomness
- flicker
- spatial distribution
- movement strategy

Example concept previously discussed:

```text
Fireplace
├── Palette
│   ├── orange
│   ├── amber
│   ├── red
│   └── warm white
│
├── Brightness: 30–85%
├── Speed: 600–1800 ms
├── Randomness: 70%
├── Flicker: enabled
└── Distribution: per-light
```

### 5.2 Timeline-driven stories

Narrative effects should be described as timelines rather than simple color fades.

Example concept:

```text
Folletto nel bosco

0–8 sec
Verde tenue e movimento lento

8–11 sec
Un lampo dorato su una sola lampada

11–20 sec
Il verde "corre" da una lampada all'altra

20–23 sec
Tutto quasi buio

23–27 sec
Tre flash dorati casuali

27–40 sec
Verde smeraldo + oro con luminosità crescente

40 sec+
Nuova sequenza casuale
```

### 5.3 Reusable event vocabulary

The engine should support reusable story/event primitives such as:

- `footsteps`
- `magic_flash`
- `hidden_treasure`
- `creature_pass`
- `surprise`
- `finale`
- ambient palette
- spatial travel/random walk
- brightness envelope
- temporary blackout/dim
- flashes
- per-light target selection
- per-zone target selection

Effects should be able to vary their event order or parameters so that long-running stories do not feel like an obvious short loop.

### 5.4 Engine capabilities planned from the beginning

The design should anticipate:

- color
- color temperature
- brightness
- palettes
- gradients
- spatial position
- per-light targeting
- room/zone targeting
- timelines
- loops
- variable-duration segments
- deterministic randomness
- seeded randomness
- surprise events
- smooth transitions
- fast transitions
- audio cues
- optional synchronized audio
- user triggers
- live audio triggers
- adaptive mapping to available Hue capabilities

## 6. Example thematic collections

Potential collections discussed include:

- **Magic & Fantasy**
- **Haunted**
- **Christmas Stories**
- **Pirates**
- **Space Adventures**
- **Dinosaurs**
- **Fairy Tales**
- **Jungle**
- **Underwater**
- **Supernatural**
- **Relax**
- **Party**
- **Nature**
- **Everyday**
- **Holidays**
- **Kids**

These are working categories, not final store taxonomy.

## 7. Candidate effects discussed

### Nature / ambience

- Ocean
- Aurora
- Sunset
- Fireplace
- Candle-like flicker

### Party / kinetic

- Party
- Disco
- Lightning
- Music Reactive
- Beat-reactive color

### Narrative / fantasy

- Folletto nel bosco
- Tesoro nascosto
- Fata incantata
- Goblin nella miniera
- Drago addormentato
- Emerald Trickster

### Narrative / haunted

- Fantasma dispettoso
- Casa stregata
- Mostro in casa
- supernatural sequences

### Seasonal

- Elfi di Natale
- other Christmas Stories
- future holiday-specific content

### Adventure

- Caccia al tesoro
- Pirates
- Space Adventures
- Dinosaurs
- Jungle
- Underwater

## 8. Music Sync

A future advanced mode should use the phone microphone to analyze live audio.

Potential extracted features:

- beat
- overall volume
- bass
- mids
- highs

These can drive:

- brightness
- color
- pulses
- movement
- per-light distribution

High-frequency output should use Hue Entertainment streaming when practical.

## 9. Initial information architecture

Early navigation concept:

```text
LumiFX
│
├── Home
│   ├── Scenes
│   ├── Stories
│   └── Interactive
│
├── Rooms / Zones
├── Favorites
├── Effect Editor (later)
└── Settings
    ├── Hue Bridge
    ├── Effect intensity
    ├── Transition speed
    └── Audio
```

An earlier brainstorming pass also considered home categories such as Everyday, Relax, Nature, Party, Holidays and Kids. These can coexist as catalogue filters while Scenes/Stories/Interactive remain the higher-level experience types.

## 10. First-version functionality

The original MVP discussion included:

- automatic/local Hue Bridge discovery
- bridge pairing
- room and zone loading
- light loading
- on/off
- brightness
- color temperature
- color
- visual home with large effect cards
- animated scenes
- adjustable speed
- adjustable intensity
- adjustable palettes where appropriate
- choosing rooms/lights participating in an effect
- favorites
- recent scenes
- sleep timer
- sunrise/wake effect
- effect player with play/pause
- first batch of original effects

## 11. Roadmap discussed

### Version 1

- Hue Bridge connection
- rooms
- lights
- color/brightness control
- scene playback
- approximately 20 animated effects
- favorites

### Version 1.5

- effect/scene editor
- timers
- sleep
- sunrise
- more sophisticated animation

### Version 2

- Music Sync
- beat detection
- Party/Disco effects
- deeper Hue Entertainment integration

The roadmap is provisional and may be reordered as implementation reveals technical constraints.

## 12. Commercial direction discussed

One proposed direction is to avoid making the app feel like a store that sells every individual scene separately.

A possible model discussed:

- roughly 30–40 effects free
- optional premium thematic packs
- or a single Pro purchase

This is not a final monetization decision.

The goal is for the free app to feel useful and generous while leaving room for premium content.

## 13. Branding and naming

Names brainstormed during the conversation:

- Luma
- HueFlow
- LumiFX
- Prism Lights

The repository was ultimately created as:

- **GitHub owner:** `fz1101hub`
- **Repository:** `Lumifx`
- **Visibility:** private

The current working product name is **LumiFX**.

## 14. Originality and IP principles

LumiFX can be inspired by the product category and by the general idea of imaginative Hue effects, but should not copy proprietary elements from OnSwitch or any other third-party app.

Do not copy:

- names
- artwork
- audio
- written descriptions
- authored sequences
- UI design
- proprietary assets

Instead, build:

- original themed effects
- original event sequences
- original visuals
- original sound design if audio is later added
- original naming
- original UX

Use of Philips Hue APIs remains subject to Signify/Philips Hue developer terms.

## 15. Repository workflow established

The repository was created manually by the user because the available GitHub connector could modify repositories but could not create a new one.

Repository:

`fz1101hub/Lumifx`

The assistant then:

- initialized `main` with a README
- created branch `chore/bootstrap-flutter`
- added the initial Flutter/Dart structure
- added the initial effect model
- added the first home screen
- added the first original narrative effect, **Emerald Trickster**
- added architecture documentation
- opened Pull Request #1

Pull Request:

https://github.com/fz1101hub/Lumifx/pull/1

## 16. Current implementation structure

The bootstrap branch currently includes concepts/files such as:

- `README.md`
- `.gitignore`
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/main.dart`
- `lib/src/app.dart`
- `lib/src/core/effects/effect.dart`
- `lib/src/core/effects/effect_event.dart`
- `lib/src/features/home/home_screen.dart`
- `lib/src/features/effects/catalog/builtin_stories.dart`
- `docs/ARCHITECTURE.md`

The first coded Story establishes the idea of a data-driven sequence composed of events such as ambient palettes, flashes, spatial travel and surprises.

## 17. Next implementation priorities

The next natural engineering sequence discussed is:

1. Hue Bridge discovery
2. Bridge pairing
3. domain models for rooms, zones and lights
4. basic real-light control
5. actual effect playback engine
6. first themed Story collection
7. later Entertainment streaming
8. later Music Sync / interactive effects

## 18. Product principle

The distinguishing idea for LumiFX is:

> Do not build only a remote control with pretty color presets. Build a lighting experience engine capable of telling small stories across a room.

That principle should guide architecture, content production and UX decisions.
