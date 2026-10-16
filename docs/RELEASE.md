# Releasing LumiFX

Step by step from this repository to Google Play and the App Store. Nothing
here needs to be done more than once except the "Every release" sections.

## 0. Before the first release

1. **`main` is the release branch.** Everything is merged there and the CI
   (`.github/workflows/ci.yml`) is green on it: format, analysis, tests,
   the Android release bundle and an unsigned iOS build. Tag releases from
   `main`.
2. **Privacy policy and support page** are published by
   `.github/workflows/pages.yml` on every push to `main` that changes
   `docs/PRIVACY_POLICY.md` or `site/`:
   - Privacy policy: <https://fz1101hub.github.io/Lumifx/privacy.html>
   - Support page: <https://fz1101hub.github.io/Lumifx/>

   If the "Pages" workflow fails with "Get Pages site failed" or the URL
   is a 404, turn Pages on once by hand: GitHub › Settings › Pages › Build
   and deployment › Source: **GitHub Actions**, then re-run the workflow
   from the Actions tab.
3. **CI minutes.** The iOS job runs on macOS (minutes count 10×) only on
   `main`, on pull requests, on tags, on manual runs and on pushes whose
   commit message contains `[ios]`. If a run is cancelled with "payments
   have failed or your spending limit needs to be increased", fix it in
   GitHub › Settings (account) › Billing and plans.

## 1. Android: signing key (once)

Create an upload key and keep it safe. Losing it means you cannot update
the app (Play App Signing can reset it, but it takes days).

```sh
tool/make_upload_key.sh          # asks for a password
```

It creates `~/lumifx-upload.jks`, writes `android/key.properties` (ignored
by git, never commit it) so release builds on this machine are signed, and
prints the four repository secrets to add in GitHub › Settings › Secrets
and variables › Actions › New repository secret:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the content of `~/lumifx-upload.jks.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | the password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the password |

With the secrets in place the CI signs the bundle with the upload key, so
the `android-release` artifact of any green run (kept 7 days, 90 for a
`v*` tag) can be uploaded to Play Console as it is. Without them the
release build is signed with the debug key: enough to prove it builds, not
to upload. The job summary says which key was used.

The same by hand:

```sh
keytool -genkey -v -keystore ~/lumifx-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

and `android/key.properties`:

```properties
storeFile=/absolute/path/to/lumifx-upload.jks   # or relative to android/
storePassword=********
keyAlias=upload
keyPassword=********
```

## 1b. Screenshots (every release)

The CI renders the store screenshots from the app itself, with the real
fonts, in all eight languages and three sizes (Japanese needs a system
Japanese font: the CI installs `fonts-ipafont-gothic`; locally, without
one, the Japanese screenshots are skipped): download the
`store-screenshots` artifact of any green run (Actions › the run › Artifacts).
Inside, `iphone-6.5/<lang>/` holds 1242×2688 PNGs for App Store Connect
(the 6.5" slot, accepted for every iPhone), `ipad-12.9/<lang>/` holds
2048×2732 PNGs (the 12.9" iPad slot, which App Store Connect requires
because the app runs on iPad; Play takes them as 10" tablet screenshots)
and `android-9x16/<lang>/` holds 1080×1920 PNGs for Play Console. Five
screens each: home, stories, the player, rooms with Hue scenes, the area
editor. The iPad set shows the tablet layouts (three experience tiles,
a grid of effects, the player in two panes).

To regenerate locally:

```sh
LUMIFX_SCREENSHOTS=1 flutter test test/screenshots
```

The screens, the demo bridge they show and the sizes live in
`test/screenshots/store_screenshots_test.dart`.

## 1c. Releasing from a tag (every release)

```sh
tool/tag_release.sh 1.0.1
```

sets the version in `pubspec.yaml`, commits, tags `v1.0.1` and pushes.
`.github/workflows/release.yml` then:

1. checks that the tag matches `pubspec.yaml`;
2. builds the Android bundle and APK signed with the upload key (§ 1),
   with the workflow's run number as build number, so every release has
   a higher build number than the last;
3. attaches them to a GitHub Release named after the version;
4. with `PLAY_SERVICE_ACCOUNT_JSON` set, uploads the bundle to Google
   Play's **internal testing** track;
5. with the iOS secrets set, archives the app on macOS, exports it for
   App Store Connect and uploads it to **TestFlight**.

Without the store secrets steps 4 and 5 are skipped and the packages are
still on the Release page to upload by hand (§ 3 and § 5).

**Google Play secret.** In Play Console › Setup › API access, create a
service account with the *Release manager* role (or *Release to testing
tracks* only), download its JSON key and paste the whole file into the
repository secret `PLAY_SERVICE_ACCOUNT_JSON`. The very first bundle of
the app must be uploaded by hand in the console once; after that the
workflow can upload.

**TestFlight secrets.** From Apple Developer › Certificates, IDs &
Profiles: an *Apple Distribution* certificate exported as `.p12` with a
password, and an *App Store* provisioning profile for `com.lumifx.lumifx`.
From App Store Connect › Users and Access › Integrations: an API key with
the *App Manager* role (`.p8` file, key id, issuer id). Then set:

| Secret | Value |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | `base64 < cert.p12 \| tr -d '\n'` |
| `IOS_CERTIFICATE_PASSWORD` | the `.p12` password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 < profile.mobileprovision \| tr -d '\n'` |
| `IOS_TEAM_ID` | the 10-character team id |
| `APP_STORE_CONNECT_KEY_ID` | the API key id |
| `APP_STORE_CONNECT_ISSUER_ID` | the issuer id |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `base64 < AuthKey_XXXX.p8 \| tr -d '\n'` |

The first tagged release is the test of this setup: if the `ios` job
fails, its log says which of the three steps (signing, archive, upload)
needs attention; the Android half is independent.

## 2. Android: Play Console (once)

1. Create the app in [Play Console](https://play.google.com/console):
   name **LumiFX**, default language English (United Kingdom or United
   States), app, free.
2. Fill in from `docs/STORE_LISTING.md`: store listing (both languages),
   data safety, content rating, target audience, privacy policy URL
   (<https://fz1101hub.github.io/Lumifx/privacy.html>), category, contact
   e-mail.
3. Upload graphics: icon 512×512 (`assets/icon/icon.png` resized), feature
   graphic `assets/icon/feature_graphic.png`, the phone screenshots
   from § 1b (`android-9x16/<lang>/`) and, optionally, the tablet ones
   (`ipad-12.9/<lang>/` as 10" tablet screenshots), per language.
4. Let Play manage the signing key (default, "Play App Signing").
5. App content › Foreground service permissions: declare the
   `mediaProjection` service and the `connectedDevice` + `microphone`
   playback service with the answers and the demo videos described in
   `docs/STORE_LISTING.md` (Play blocks the release until this is done,
   because the app targets Android 14+ and declares those service types).

## 3. Android: every release

```sh
flutter clean
flutter pub get
flutter build appbundle --release
```

The bundle is at `build/app/outputs/bundle/release/app-release.aab`. Or,
with the signing secrets set (§ 1), push a `v*` tag and download the
`android-release` artifact from that CI run. Upload it to **Testing ›
Internal testing** first, install it from the
opt-in link on a phone with a Hue Bridge, run through `docs/QA_CHECKLIST.md`,
then promote to Production.

## 4. iOS: Apple Developer setup (once)

1. Enrol in the Apple Developer Program (99 $/year) with the Apple ID that
   will own the app.
2. In [App Store Connect](https://appstoreconnect.apple.com) › Apps › **+**:
   platform iOS, name **LumiFX**, primary language English, bundle ID
   `com.lumifx.lumifx` (create it in Certificates, Identifiers & Profiles
   first with the App ID, no special capabilities needed), SKU `lumifx`.
3. Fill in from `docs/STORE_LISTING.md`: description, keywords, support URL
   (<https://fz1101hub.github.io/Lumifx/>), privacy policy URL
   (<https://fz1101hub.github.io/Lumifx/privacy.html>), App Privacy
   ("Data Not Collected"), age rating, category, review notes.
4. Upload the screenshots from § 1b for each language: `iphone-6.5/<lang>/`
   (the 6.5" set covers every iPhone size) and `ipad-12.9/<lang>/` (the
   12.9" set covers every iPad; App Store Connect insists on it because
   the app supports iPad). Leave "Mac" ticked under Availability only if
   you have tried the app on an Apple-silicon Mac; it is untested there.

## 5. iOS: every release (needs a Mac with Xcode)

```sh
flutter clean
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

In Xcode: select the Runner target › Signing & Capabilities › tick
"Automatically manage signing" and choose your team (do this once; Xcode
writes it into the project file, commit it). Then **Product › Archive**,
and in the Organizer **Distribute App › App Store Connect › Upload**.

Or from the command line, once signing is set up in Xcode:

```sh
flutter build ipa --release
# upload build/ios/ipa/*.ipa with Transporter.app or:
xcrun altool --upload-app -f build/ios/ipa/LumiFX.ipa -t ios \
  --apiKey <key id> --apiIssuer <issuer id>
```

In App Store Connect, add the build to the version, use **TestFlight** on a
phone with a Hue Bridge, run through `docs/QA_CHECKLIST.md`, then
**Submit for Review**.

## 6. Version numbers

`pubspec.yaml` holds `version: 1.0.0+1` → marketing version 1.0.0, build 1.
Bump the version (1.0.1, 1.1.0) when the app changes for users and release
it with `tool/tag_release.sh` (§ 1c): the build number is set by the
Release workflow from its run number, so it is always higher than the
last upload. For a build made by hand, pass `--build-number` to
`flutter build` with a number above the last one in the stores.

## 7. What the stores will ask that is not obvious

- **iOS local network prompt.** iOS shows "LumiFX would like to find and
  connect to devices on your local network" the first time the app
  searches for a bridge. If the reviewer denies it, discovery finds
  nothing; the manual IP entry still works and the preview mode needs no
  bridge at all. This is explained in the review notes.
- **Microphone.** Only requested when a Music Sync effect starts. Both
  stores accept this as long as the purpose string explains it (it does).
- **Camera.** Only requested when TV Sync starts; the purpose string
  (`NSCameraUsageDescription`) explains it. On Android the camera is
  marked not required, so phones and tablets without one can still
  install the app.
- **Export compliance.** See STORE_LISTING.md; `ITSAppUsesNonExemptEncryption`
  is set to false so TestFlight does not ask every time.
- **Trademark.** The listing says the app is not affiliated with Signify.
  Do not use the Hue logo, Signify product photos, or "Hue" as the first
  word of the app name.

## 8. Rollback and hotfix

- Play: Production › Releases › the previous release › "Resubmit" is not
  possible for bundles; instead, bump the build number and upload the
  previous commit rebuilt. Keep tags for every release.
- App Store: Versions are immutable; submit a new build with a higher build
  number. Use "Expedited review" only for crashes.
