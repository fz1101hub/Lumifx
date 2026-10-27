# LumiFX on the watch

What a watch can do with LumiFX today, without an app of its own, and
what a native watch app would need.

## Wear OS (Android)

While an effect plays with "Keep playing with the screen off" on, the
phone shows a notification with **Stop**, **Next favourite** (when there
are favourites) and **Bedtime**. Wear OS shows the phone's notifications
on a paired watch with their actions, so from the wrist:

- Stop ends the effect and puts the lights back;
- Next favourite plays the next of the favourites (round and round,
  only those allowed in kids mode);
- Bedtime starts bedtime as the bedtime link does.

The buttons are handled by `PlaybackService` (actions
`PLAYBACK_FAVOURITE`, `PLAYBACK_BEDTIME`) and reach the app through
`com.lumifx/background` (`action`), see `_backgroundAction` in `app.dart`.

## Apple Watch

- The Live Activity of the effect playing (lock screen, Dynamic Island)
  also appears in the watch's Smart Stack on watchOS 11 and later, once
  the widget extension is set up (see `docs/IOS_WIDGET.md`).
- Siri phrases ("Bedtime in LumiFX", "Stop LumiFX") are the iPhone's App
  Shortcuts; on the watch, Siri hands them to the iPhone.

## A native watch app (not built yet)

Both would talk to the phone, which keeps driving the lights (effects
are rendered by the app):

- **Wear OS**: a `wear` Gradle module (Compose for Wear OS) with a list
  of favourites, Stop and Bedtime, sending messages over the Wearable
  Data Layer (`play-services-wearable`, MessageClient) to a
  `WearableListenerService` in the phone app that opens the matching
  `lumifx://` link. Needs the module in `android/settings.gradle`, a
  separate Play listing track for Wear OS and screenshots.
- **watchOS**: a watchOS app target (SwiftUI) added in Xcode (like the
  widget extension, it cannot be added from the command line reliably),
  using WatchConnectivity (`WCSession.sendMessage`) to a session delegate
  in `AppDelegate.swift` that forwards the request on a method channel.
  The favourites' names would be sent to the watch with
  `updateApplicationContext` whenever they change.
