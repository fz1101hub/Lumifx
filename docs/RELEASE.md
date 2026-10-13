# Releasing LumiFX

Step by step from this repository to Google Play and the App Store. Nothing
here needs to be done more than once except the "Every release" sections.

## 0. Before the first release

1. **Merge to `main`.** Open a pull request from `ccr-eb022f2a-u0r6sq` (after
   PR #1 is merged) and merge it. Tag releases from `main`.
2. **Host the privacy policy.** Both stores need a public URL. Options, in
   order of simplicity:
   - Create a public repository (e.g. `fz1101hub/lumifx-site`), enable
     GitHub Pages, and put the content of `docs/PRIVACY_POLICY.md` there as
     `privacy.html` or `privacy.md`.
   - Or paste it into any static host (Netlify, Cloudflare Pages, a blog).
   Note the URL; it goes into both store consoles.
3. **Unblock the CI.** `.github/workflows/ci.yml` builds the Android bundle
   and an unsigned iOS build, but every run so far failed within seconds
   with GitHub's message "The job was not started because recent account
   payments have failed or your spending limit needs to be increased". Fix
   it in GitHub › Settings (account) › Billing and plans: check the payment
   method and raise the Actions spending limit above $0 (private
   repositories consume paid minutes once the free quota is used; macOS
   minutes count 10×). Then re-run the latest workflow from the Actions
   tab. Until a run is green, the Android and iOS builds have not been
   verified by anyone: do the first `flutter build appbundle` and the iOS
   archive on a machine and fix whatever they report before uploading.

## 1. Android: signing key (once)

Create an upload key and keep it safe. Losing it means you cannot update
the app (Play App Signing can reset it, but it takes days).

```sh
keytool -genkey -v -keystore ~/lumifx-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Create `android/key.properties` (ignored by git, never commit it):

```properties
storeFile=/absolute/path/to/lumifx-upload.jks   # or relative to android/
storePassword=********
keyAlias=upload
keyPassword=********
```

`android/app/build.gradle.kts` picks it up automatically; without it the
release build is signed with the debug key (fine for CI, not uploadable).

## 2. Android: Play Console (once)

1. Create the app in [Play Console](https://play.google.com/console):
   name **LumiFX**, default language English (United Kingdom or United
   States), app, free.
2. Fill in from `docs/STORE_LISTING.md`: store listing (both languages),
   data safety, content rating, target audience, privacy policy URL,
   category, contact e-mail.
3. Upload graphics: icon 512×512 (`assets/icon/icon.png` resized), feature
   graphic `assets/icon/feature_graphic.png`, at least 2 phone screenshots.
4. Let Play manage the signing key (default, "Play App Signing").

## 3. Android: every release

```sh
flutter clean
flutter pub get
flutter build appbundle --release
```

The bundle is at `build/app/outputs/bundle/release/app-release.aab`.
Upload it to **Testing › Internal testing** first, install it from the
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
   (can be the privacy policy site), privacy policy URL, App Privacy
   ("Data Not Collected"), age rating, category, review notes.
4. Upload screenshots for the required iPhone sizes.

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
For every upload to either store, increase the build number (`+2`, `+3`...),
and bump the version (1.0.1, 1.1.0) when the app changes for users. Both
platforms read these values from `pubspec.yaml`. Tag the commit
(`git tag v1.0.0 && git push --tags`) so the CI keeps the artifacts.

## 7. What the stores will ask that is not obvious

- **iOS local network prompt.** iOS shows "LumiFX would like to find and
  connect to devices on your local network" the first time the app
  searches for a bridge. If the reviewer denies it, discovery finds
  nothing; the manual IP entry still works and the preview mode needs no
  bridge at all. This is explained in the review notes.
- **Microphone.** Only requested when a Music Sync effect starts. Both
  stores accept this as long as the purpose string explains it (it does).
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
