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

## Content policy

Effects and visual assets should be original. Inspiration can come from broad themes and genres, but proprietary names, artwork, audio and authored sequences from third-party apps should not be copied.
