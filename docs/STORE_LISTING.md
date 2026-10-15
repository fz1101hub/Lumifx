# Store listing

Everything to paste into Google Play Console and App Store Connect. Keep the
two stores in sync when you change anything here.

## Identity

| | Value |
|---|---|
| App name | LumiFX |
| Android package | `com.lumifx.lumifx` |
| iOS bundle id | `com.lumifx.lumifx` |
| Category | Lifestyle (Play) · Lifestyle (App Store), secondary Utilities |
| Price | Free |
| Privacy policy URL | <https://fz1101hub.github.io/Lumifx/privacy.html> (published from `docs/PRIVACY_POLICY.md`, see RELEASE.md § 0) |
| Support URL | <https://fz1101hub.github.io/Lumifx/> |
| Support e-mail | fz1101hub@gmail.com |
| Content rating | Everyone / 4+ (no user content, no ads, no purchases) |

Not affiliated with Signify. "Philips Hue" is a trademark of Signify
Holding; the listing must say so and must not use Hue logos or product
photos.

## English

**Subtitle / short description (max 30 chars App Store, 80 Play)**

> Stories and scenes for Philips Hue

**Promotional text (App Store, 170 chars)**

> Turn your room into a thunderstorm, a haunted house or a dance floor.
> Original lighting stories for Philips Hue, with Music Sync.

**Description**

> LumiFX turns Philips Hue lights into an experience, not just a remote
> control.
>
> SCENES
> Fireplace, Ocean, Aurora, Sunset, Thunderstorm, Disco: living atmospheres
> that keep moving for as long as you like.
>
> STORIES
> Short lighting tales that unfold around the room: a trickster hiding in
> the forest, a sleeping dragon, a haunted manor on a stormy night,
> Christmas elves, a treasure hunt, a kraken under the ship, a meteor
> shower, dinosaurs approaching, the deep sea at night. Every pass of a
> story is a little different.
>
> MUSIC SYNC
> Beat Pulse, Party Chase, Spectrum and Mood Glow listen to the music in
> the room and move the lights with it. Audio is analysed on your phone
> and never recorded.
>
> MADE FOR HUE
> • Finds and pairs with your Hue Bridge on your Wi-Fi, no account needed.
> • Plays on any room or zone, and streams fast effects to Entertainment
>   areas (50 updates per second).
> • Create and edit Entertainment areas in the app, placing lights on a map
>   of the room.
> • Adjust brightness, intensity and speed while an effect plays.
> • Favourites, recently played, and your lights are put back the way they
>   were when an effect stops.
> • Preview every effect on screen before playing it on real lights.
>
> Requires a Philips Hue Bridge (square model) and colour or white-ambiance
> Hue lights on the same Wi-Fi network. Entertainment areas need Hue lights
> that support streaming.
>
> LumiFX is an independent app and is not affiliated with Signify. Philips
> Hue is a trademark of Signify Holding B.V.

**Keywords (App Store, 100 chars)**

> hue,philips hue,lights,smart lights,scenes,mood lighting,music sync,party,ambient,bridge

**What's new (1.0.0)**

> First release: 6 scenes, 12 stories, 4 Music Sync effects, Entertainment
> streaming and an area editor.

## Italiano

**Sottotitolo / descrizione breve**

> Storie e scene per Philips Hue

**Testo promozionale**

> Trasforma la stanza in un temporale, una casa stregata o una pista da
> ballo. Storie di luce originali per Philips Hue, con Music Sync.

**Descrizione**

> LumiFX trasforma le luci Philips Hue in un'esperienza, non in un semplice
> telecomando.
>
> SCENE
> Camino, Oceano, Aurora, Tramonto, Temporale, Disco: atmosfere vive che
> continuano a muoversi finché vuoi.
>
> STORIE
> Brevi racconti di luce che si svolgono intorno alla stanza: un folletto
> nascosto nel bosco, un drago addormentato, una villa stregata in una notte
> di tempesta, gli elfi di Natale, una caccia al tesoro, un kraken sotto la
> nave, una pioggia di meteore, dinosauri in avvicinamento, gli abissi di
> notte. Ogni ripetizione di una storia è un po' diversa.
>
> MUSIC SYNC
> Beat Pulse, Party Chase, Spectrum e Mood Glow ascoltano la musica nella
> stanza e muovono le luci a tempo. L'audio è analizzato sul telefono e non
> viene mai registrato.
>
> FATTA PER HUE
> • Trova e collega il tuo Bridge Hue sul Wi-Fi, senza account.
> • Funziona su qualsiasi stanza o zona e invia gli effetti veloci alle
>   aree Entertainment (50 aggiornamenti al secondo).
> • Crea e modifica le aree Entertainment nell'app, posizionando le luci su
>   una mappa della stanza.
> • Regola luminosità, intensità e velocità mentre l'effetto è in corso.
> • Preferiti, riprodotti di recente, e le luci tornano com'erano quando
>   l'effetto si ferma.
> • Anteprima di ogni effetto sullo schermo prima di usarlo sulle luci vere.
>
> Richiede un Bridge Philips Hue (modello quadrato) e luci Hue a colori o
> white ambiance sulla stessa rete Wi-Fi. Le aree Entertainment richiedono
> luci Hue compatibili con lo streaming.
>
> LumiFX è un'app indipendente e non è affiliata a Signify. Philips Hue è un
> marchio di Signify Holding B.V.

**Parole chiave**

> hue,philips hue,luci,luci smart,scene,atmosfera,music sync,festa,ambiente,bridge

**Novità (1.0.0)**

> Prima versione: 6 scene, 12 storie, 4 effetti Music Sync, streaming
> Entertainment ed editor delle aree.

## Google Play: Data safety form

- Does your app collect or share any of the required user data types? **No.**
- Is all of the user data collected by your app encrypted in transit?
  (asked anyway) **Yes.**
- Do you provide a way for users to request that their data is deleted?
  **Not applicable: no data is collected.** If forced to answer: Yes,
  "Forget this bridge" and uninstalling remove everything.
- Microphone: the app uses RECORD_AUDIO but does not collect audio. In the
  data types list, do **not** declare "Audio files" or "Voice or sound
  recordings"; audio is processed ephemerally on device and never stored
  or sent (Play's definition of "collected" excludes ephemeral processing).
- Advertising ID: not used.

**Permissions declaration:** none of the sensitive permissions (SMS, call
log, location, all files) are requested. RECORD_AUDIO needs no separate
declaration form.

**Content rating questionnaire:** no violence, no sexual content, no
language, no controlled substances, no user interaction, no sharing of
location, no purchases. Result: Everyone (ESRB) / PEGI 3.

**Target audience:** 18 and over (simplest; the app is not designed for
children). Do not tick "designed for families".

## App Store Connect: App Privacy

- Data collection: **Data Not Collected.** (Microphone audio is processed
  on device and not stored; bridge credentials never leave the device.)
- Tracking: **No.**
- Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy` (no tracking, no
  collected data, UserDefaults reason CA92.1).

**Export compliance:** `ITSAppUsesNonExemptEncryption` is `false`, so
TestFlight does not ask on every build. The app uses only standard
algorithms: TLS to the bridge (OS), OS secure storage, and AES-128-GCM for
the Hue DTLS stream, implemented with the open-source `pointycastle`
library rather than taken from the OS. Standard, non-proprietary
encryption falls under mass-market category 5D992.c: exempt from Apple's
documentation requirements, but US law expects an annual self-
classification report to BIS/NSA (a short e-mail; see Apple's "Complying
with Encryption Export Regulations"). If you prefer to be asked every
time, remove the key from `ios/Runner/Info.plist` and answer in App Store
Connect: uses encryption → yes; proprietary algorithms → no; standard
algorithms → yes; not a French app.

**Mac availability:** the app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)
but App Store Connect offers it on Apple-silicon Macs by default. Untick
"Make this app available on Mac" (Pricing and Availability) unless you have
tested microphone and local-network access on a Mac.

**Age rating:** answer "None" to every question → 4+.

## Review notes (both stores)

Paste this in "Notes for review":

> LumiFX controls Philips Hue lights on the reviewer's local Wi-Fi network.
> No account or login is needed. Without a Hue Bridge the app still works
> in preview mode: open Scenes, Stories or Interactive, choose any effect
> and press Play to see it animate on the virtual lamps on screen. "Play
> on" stays on "Preview only" when no bridge is paired.
>
> Local-network permission (iOS) is needed to discover and talk to the Hue
> Bridge. Microphone permission is requested only when a Music Sync effect
> is started; audio is analysed in real time on the device and never
> recorded or transmitted.
>
> The app is not affiliated with Signify / Philips Hue.

## Screenshots

Required: iPhone 6.7" (1290×2796) and 6.5"/6.9" sets, Android phone
(1080×1920 or similar), plus the 1024×500 Play feature graphic in
`assets/icon/feature_graphic.png`.

Suggested shots (take them on a device or simulator with a bridge paired;
preview mode works for the player shots):

1. Home with Favourites and Recently played.
2. Stories list (palette cards).
3. Player with the lamp preview mid-effect (Thunderstorm or Haunted Manor).
4. Music Sync player with the level meters and BPM.
5. Entertainment area editor with lights on the room map.
6. Settings.
