# iOS home-screen widget: the last step (needs a Mac and your Apple account)

The Android widget is complete. On iOS everything is ready except the one
part that needs your Apple developer account: an **App Group** shared by
the app and the widget, and the widget target in Xcode.

What already exists:

- `ios/LumiFXWidget/LumiFXWidget.swift` and `Info.plist`: the widget
  (medium size, up to four favourites, a tap plays the effect through a
  `lumifx://` link).
- `ios/Runner/AppDelegate.swift`: the app writes the widget's content to
  the group `group.com.lumifx.lumifx` and reloads the widget whenever the
  favourites change.

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
   two files from `ios/LumiFXWidget/` instead (drag them in, target
   membership LumiFXWidget only).
5. **Runner target › Signing & Capabilities › + Capability › App
   Groups**: tick `group.com.lumifx.lumifx`. Do the same on the
   **LumiFXWidget** target.
6. Run on a device, add the widget from the home screen (long press ›
   + › LumiFX), star an effect in the app: it appears on the widget.

## Releasing with the widget

The extension has its own bundle id, so it needs its own App Store
provisioning profile (with the App Group). Create it like the app's
(`docs/RELEASE.md` § 4) and, for the tag release workflow, add it as the
secret `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`, then extend the
`Install the provisioning profile` step of `.github/workflows/release.yml`
to install both profiles and list both in `ExportOptions.plist` under
`provisioningProfiles`. Until then, leave the widget target out and
releases keep working as they do now.
