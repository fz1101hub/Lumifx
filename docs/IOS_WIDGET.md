# iOS home-screen widget: the last step (needs a Mac and your Apple account)

The Android widget is complete. On iOS everything is ready except the one
part that needs your Apple developer account: an **App Group** shared by
the app and the widget, and the widget target in Xcode.

What already exists:

- `ios/LumiFXWidget/LumiFXWidget.swift` and `Info.plist`: the widget
  (medium size, up to four favourites, a tap plays the effect through a
  `lumifx://` link). The extension's `@main` is the widget bundle
  `LumiFXWidgets`: the favourites widget plus, from iOS 16.1, the Live
  Activity.
- `ios/LumiFXWidget/PlayingLiveActivity.swift`: the effect playing on
  the lock screen and in the Dynamic Island, with its room, colours and
  a Stop (a `lumifx://app/stop` link).
- `ios/Runner/AppDelegate.swift`: the app writes the widget's content to
  the group `group.com.lumifx.lumifx` and reloads the widget whenever the
  favourites change, and starts, updates and ends the Live Activity
  (`LiveActivityBridge`; `NSSupportsLiveActivities` is in the app's
  `Info.plist`).

## Steps (about 15 minutes)

1. **Apple Developer › Identifiers › App Groups**: create
   `group.com.lumifx.lumifx`.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. **File › New › Target › Widget Extension**. Product name
   `LumiFXWidget`, untick "Include Live Activity" and "Include
   Configuration App Intent", embed in **Runner**. Bundle id
   `com.lumifx.lumifx.LumiFXWidget`, deployment target iOS 15.
4. Xcode creates a `LumiFXWidget` folder with sample files: delete the
   generated `.swift` files and `Info.plist` from the target, and add the
   three files from `ios/LumiFXWidget/` instead (`LumiFXWidget.swift`,
   `PlayingLiveActivity.swift`, `Info.plist`; drag them in, target
   membership LumiFXWidget only).
5. **Runner target › Signing & Capabilities › + Capability › App
   Groups**: tick `group.com.lumifx.lumifx`. Do the same on the
   **LumiFXWidget** target.
6. Run on a device, add the widget from the home screen (long press ›
   + › LumiFX), star an effect in the app: it appears on the widget.

## Lock screen (Live Activity)

Live Activities need iOS 16.1 on the phone. The extension's deployment
target can stay iOS 15: `PlayingLiveActivity` is marked for 16.1 and the
bundle adds it only there. If Xcode complains about the `if #available`
in `LumiFXWidgets`, set the extension's target to 16.1 (the favourites
widget then needs 16.1 too). No capability or App ID change is needed:
the app updates the activity itself, without push.

To test: on an iPhone with iOS 16.1 or later, with "Keep playing with
the screen off" on in LumiFX's Settings, play an effect on a room and
lock the phone. The lock screen shows the effect, the room, its colours
and Stop; on an iPhone with a Dynamic Island it sits there too (long
press to expand). Stop opens LumiFX, which stops and puts the lights
back. Effects without sounds stop when the phone locks, and the activity
goes with them; one with sounds, or a lullaby, keeps playing.

## Releasing with the widget

The extension has its own bundle id, so it needs its own App Store
provisioning profile (with the App Group). Create it like the app's
(`docs/RELEASE.md` § 4) and, for the tag release workflow, add it as the
secret `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`, then extend the
`Install the provisioning profile` step of `.github/workflows/release.yml`
to install both profiles and list both in `ExportOptions.plist` under
`provisioningProfiles`. Until then, leave the widget target out and
releases keep working as they do now, only without the widget and the
lock screen Live Activity (effects with sounds still keep playing with
the phone locked).
