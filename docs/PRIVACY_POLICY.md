# LumiFX Privacy Policy

_Last updated: 18 October 2026_

LumiFX is an app that plays lighting effects on Philips Hue lights. It is
designed to work on your phone and your home network. We do not run
servers, we do not have accounts, and we do not collect, store or sell any
personal data. The only thing that ever leaves your home network is
described under "Weather lights" below, and only if you use them.

## What the app does with data

**Hue Bridge credentials.** When you pair LumiFX with your Hue Bridge, the
bridge gives the app an application key and a streaming key. They are stored
in your phone's secure storage (Keychain on iOS, Keystore-backed storage on
Android) and are sent only to your bridge, over your local network. They are
removed when you choose "Forget this bridge" or uninstall the app.

**Lights, rooms and entertainment areas.** The app reads the names and state
of your lights, rooms, zones and entertainment areas from your bridge to show
them and to control them. This information stays on your phone and your
bridge.

**Microphone (Music Sync).** If you start a Music Sync effect, the app asks
for microphone access and analyses the sound in the room to detect beats and
loudness. Audio is processed in real time on your phone and is never
recorded, stored or transmitted. The microphone is used only while a Music
Sync effect is playing and is switched off when you pause or stop it.

**Microphone (birthday party).** At a birthday party you can tap "Blow on
the phone" so the candles go out when someone blows on the microphone. The
app only measures how loud the sound is, on your phone; nothing is
recorded, stored or transmitted, and the microphone is switched off as soon
as the candles are out or you leave the party.

**Microphone (noise light).** The noise light turns the lamps green, amber
or red by how loud the room is. The app only measures the loudness, on
your phone; nothing is recorded, stored or transmitted, and the
microphone is switched off when you tap Stop or leave the noise light.

**Your voice (stories of your own).** In the story editor you can record
yourself reading the lines of a story you made. The recordings are saved
as sound files on your phone only, play when that story plays, are never
uploaded or shared (not even when you share the story), and are deleted
with the story or one by one. On iPhone they may be part of your own
iCloud device backup, like other app data; Android backups are off for
LumiFX.

**Photos (scene from a photo).** In the scene editor, "From a photo" lets
you choose a photo or take one. The app reads its main colours on your
phone; the photo is not kept, copied or sent anywhere.

**Reading stories aloud.** If you switch on "Read aloud", the words of the
stories and game calls are read by your phone's own text-to-speech voice.
LumiFX sends them nowhere (depending on your phone's settings, its speech
engine may use an online voice).

**Story maker, learning games and party games.** The story maker puts
each story together on your phone from sentences written into the app;
it uses no AI and no internet connection, and the hero's name you type
is used only in that story and is not saved (you can also pick one of
the children's names described under "Children's profiles and the star
shop"). Count the lights, Colours in another language, Secret messages,
Hot and cold and the Light piano also run entirely on your phone. The
numbers, the colour words, the calls of Hot and cold and, with "Read
aloud" on, the lines of the story are spoken by your phone's own
text-to-speech voice, as described above.

**Children's profiles and the star shop.** If you add children to the
morning and evening routines, their names (as you type them), their
routine steps, the stars they earn and spend, and the rewards and costs
you set in the star shop are stored on your phone only, with the other
preferences, and are never sent anywhere. On iPhone, like other app
data, they may be part of your own iCloud device backup. Removing a
child deletes their stars and steps; uninstalling the app deletes
everything. The bedtime ritual puts the chosen child's name in
tonight's story, on your phone.

**Motion sensor (Halloween party).** At a Halloween party you can choose
one of your Hue motion sensors. While the party screen is open, LumiFX
listens to your Hue Bridge's event stream on your local network to know
when that sensor sees someone, and answers with a scare on your lights.
It uses only the motion reports; nothing is recorded, stored or sent
anywhere else, and it stops listening when you leave the party screen.

**Weather lights.** If you use Weather lights, the city name you type in
the search is sent to Open-Meteo (open-meteo.com) to find matching places,
and the coordinates of the place you choose are sent to Open-Meteo to get
its weather. The app never uses your phone's location. The chosen place is
stored on your phone only, until you change it or uninstall the app.
Open-Meteo is an independent weather service with its own terms
(open-meteo.com/en/terms).

**Phone audio (Music Sync, Android 10 and later).** In Settings you can let
Music Sync follow the sound your phone itself is playing instead of the
room. Android then asks you to allow "screen capture" each time: LumiFX
uses this permission only to receive the sound of other apps, shows an
ongoing notification while it does, and never captures the screen. That
sound is analysed in real time in the same way as the microphone and is
never recorded, stored or transmitted. Capture ends when you pause or stop
the effect or dismiss it from the notification.

**Camera (TV Sync).** If you start TV Sync, the app asks for camera
access and looks at your TV through the phone's camera so the lights can
take its colours. A few thousand pixels of each frame are averaged on your
phone, about ten times a second; the picture is never recorded, stored or
transmitted. The camera is used only while TV Sync plays on screen and is
switched off when you pause or stop it, or leave the app.

**Playing with the screen off (Android).** While an effect plays on your
lights, LumiFX can keep running with the screen off. It then shows a
notification (Android 13 and later ask once for permission to show it) and,
during a Music Sync effect, keeps using the microphone exactly as described
above. You can turn this off in Settings.

**Lock screen and playing with the iPhone locked.** While an effect plays
on your lights, iPhones with iOS 16.1 or later can show it on the lock
screen and in the Dynamic Island (a Live Activity): the effect's name,
the room, its colours and a Stop button, visible without unlocking the
phone. The app creates and updates it on your phone and sends nothing
anywhere to show it (no push service is used). Effects with sounds or a
tune keep playing while the iPhone is locked, because iOS lets an app
run in the background while it plays sound; effects without sounds
(Music Sync among them) still stop when the iPhone locks. Both follow "Keep playing with the screen off" in
Settings, and Live Activities can also be turned off for LumiFX in the
iPhone's Settings.

**NFC stickers.** On Android, when you tap "Write on a sticker" and hold
an NFC sticker to the phone, LumiFX writes one `lumifx://` link on it,
nothing else: an effect, a playlist, bedtime or stop and, for a link you
chose with a room, that room's name. Anyone who touches the sticker with
a phone can read that link. When your unlocked phone touches a sticker,
Android opens LumiFX with the link stored on it; LumiFX uses only that
link and reads nothing else from the sticker. On iPhone, LumiFX does not use NFC: the Shortcuts
app reads the sticker and opens the link you copied into it.

**Notification lights (Android).** If you choose apps and allow LumiFX
"notification access" in Android's settings, Android tells LumiFX
whenever an app posts a notification. LumiFX looks only at which app
posted it (its package name, such as `com.whatsapp`) to check whether it
is one you chose; it never reads the title, the text or anything else in
the notification. For a chosen app it sends a flash command (which
lights, which colour) to your Hue Bridge on your local network, also
while LumiFX is closed. Nothing about your notifications is stored or
transmitted anywhere else. To let you choose, the app lists the apps in
your phone's app drawer; that list is shown on your phone only. The
settings needed to flash the lights with LumiFX closed (your bridge's
address and key, the lights, and the apps and colours you chose) are
stored on your phone only, encrypted with a key kept in the Android
Keystore. You can switch Notification lights off in LumiFX, and revoke
notification access at any time in Android's settings (usually Apps ›
Special app access › Notification access, called "Device & app
notifications" on some phones), or by uninstalling the app. Android
warns that an app with this access could read all notifications;
LumiFX does not. iPhones do not let any app see notifications, so the
feature is not offered there.

**Sharing scenes, stories and playlists.** When you choose to share, the
scene, story or playlist is packed into a link or QR code that you pass on
yourself. It contains only the names, colours, words and settings you
made; LumiFX sends it nowhere.

**Routines and Hue scenes.** Wake-up and bedtime routines and saved Hue
scenes are stored on your own Hue Bridge, like those made in the Hue app.

**Preferences.** Favourites, recently played effects, playback settings,
the stars and steps of the morning and evening routines, the children's
names, the star shop's rewards, the bedtime ritual's choices, and the
scenes and stories you make are stored on your phone only.

## Network connections

- **Your Hue Bridge** on your local Wi-Fi network (HTTPS and, for fast
  effects, an encrypted DTLS stream). Notification lights send their
  flash commands to it over HTTPS too, and the Halloween party listens
  to its event stream for motion.
- **discovery.meethue.com**, a service operated by Signify (Philips Hue),
  which helps find bridges on your network. The request contains no
  personal data beyond what any web request contains (your public IP
  address). You can skip it by entering the bridge address by hand.
- **geocoding-api.open-meteo.com** and **api.open-meteo.com**, only when
  you use Weather lights: the city name you search for and the
  coordinates of the place you choose, as described above.

The app makes no other network connections. It contains no analytics, no
advertising, no crash reporting and no tracking of any kind.

## Children

LumiFX does not collect personal data from anyone, including children.
The children's names you add to the routines stay on your phone.
Weather lights send only a place name and its coordinates to Open-Meteo,
never anything that identifies a person.

## Changes

If this policy changes, the new version will be published at the same
address with a new date.

## Contact

Questions about privacy: fz1101hub@gmail.com

---

# Informativa sulla privacy di LumiFX

_Ultimo aggiornamento: 18 ottobre 2026_

LumiFX è un'app che riproduce effetti luminosi sulle luci Philips Hue.
Funziona sul telefono e sulla rete di casa. Non abbiamo server, non
esistono account e non raccogliamo, conserviamo né vendiamo alcun dato
personale. L'unica cosa che esce dalla rete di casa è descritta sotto
"Meteo in luce", e solo se lo usi.

## Che cosa fa l'app con i dati

**Credenziali del Bridge Hue.** Quando colleghi LumiFX al Bridge, il Bridge
assegna all'app una chiave applicativa e una chiave per lo streaming. Sono
salvate nell'archivio sicuro del telefono (Keychain su iOS, Keystore su
Android) e vengono inviate solo al tuo Bridge, sulla rete locale. Vengono
eliminate con "Dimentica questo Bridge" o disinstallando l'app.

**Luci, stanze e aree Entertainment.** L'app legge dal Bridge nomi e stato di
luci, stanze, zone e aree Entertainment per mostrarli e controllarli. Queste
informazioni restano sul telefono e sul Bridge.

**Microfono (Music Sync).** Se avvii un effetto Music Sync, l'app chiede
l'accesso al microfono e analizza il suono nella stanza per riconoscere beat
e volume. L'audio è elaborato in tempo reale sul telefono e non viene mai
registrato, salvato o trasmesso. Il microfono è attivo solo mentre un effetto
Music Sync è in riproduzione e viene spento in pausa o allo stop.

**Microfono (festa di compleanno).** Alla festa di compleanno puoi toccare
"Soffia sul telefono" perché le candeline si spengano quando qualcuno soffia
sul microfono. L'app misura solo quanto è forte il suono, sul telefono;
nulla viene registrato, salvato o trasmesso, e il microfono si spegne appena
le candeline sono spente o lasci la festa.

**La tua voce (storie create da te).** Nell'editor delle storie puoi
registrarti mentre leggi le frasi di una storia che hai creato. Le
registrazioni sono salvate come file audio solo sul telefono, si sentono
quando quella storia è in riproduzione, non vengono mai caricate né
condivise (neanche quando condividi la storia) e si eliminano con la storia
o una per una. Su iPhone possono far parte del tuo backup iCloud del
dispositivo, come gli altri dati delle app; per LumiFX i backup Android sono
disattivati.

**Foto (scena da una foto).** Nell'editor delle scene, "Da una foto" ti fa
scegliere o scattare una foto. L'app ne legge i colori principali sul
telefono; la foto non viene conservata, copiata né inviata.

**Lettura ad alta voce.** Se attivi "Leggi ad alta voce", le parole delle
storie e i comandi dei giochi sono letti dalla voce di sintesi del telefono.
LumiFX non le invia da nessuna parte (a seconda delle impostazioni del
telefono, il motore vocale potrebbe usare una voce online).

**Inventa una storia, giochi per imparare e giochi di festa.** "Inventa
una storia" compone ogni storia sul telefono con frasi scritte nell'app;
non usa intelligenza artificiale né connessione a internet, e il nome
dell'eroe che scrivi è usato solo in quella storia e non viene salvato
(puoi anche sceglierlo tra i nomi dei bambini descritti sotto "Profili
dei bambini e negozio delle stelle"). Anche "Conta le luci", "I colori
in un'altra lingua", "Messaggi segreti", "Acqua o fuoco" e il
"Pianoforte luminoso" funzionano interamente sul telefono. I numeri, i
nomi dei colori, le parole di "Acqua o fuoco" e, con "Leggi ad alta
voce" attivo, le frasi della storia sono pronunciati dalla voce di
sintesi del telefono, come descritto sopra.

**Profili dei bambini e negozio delle stelle.** Se aggiungi dei bambini
alle routine del mattino e della sera, i loro nomi (come li scrivi), i
passi delle loro routine, le stelline che guadagnano e spendono e i
premi e i costi che imposti nel negozio delle stelle sono salvati solo
sul telefono, insieme alle altre preferenze, e non vengono mai inviati
da nessuna parte. Su iPhone, come gli altri dati delle app, possono far
parte del tuo backup iCloud del dispositivo. Rimuovere un bambino ne
elimina le stelline e i passi; disinstallare l'app elimina tutto. Il
rituale della nanna mette il nome del bambino scelto nella storia della
sera, sul telefono.

**Sensore di movimento (festa di Halloween).** Alla festa di Halloween
puoi scegliere uno dei tuoi sensori di movimento Hue. Mentre la
schermata della festa è aperta, LumiFX ascolta il flusso di eventi del
tuo Hue Bridge sulla rete locale per sapere quando quel sensore vede
qualcuno, e risponde con uno spavento sulle luci. Usa solo le
segnalazioni di movimento; nulla viene registrato, salvato o inviato
altrove, e smette di ascoltare quando lasci la schermata della festa.

**Meteo in luce.** Se usi Meteo in luce, il nome della città che scrivi
nella ricerca viene inviato a Open-Meteo (open-meteo.com) per trovare i
luoghi corrispondenti, e le coordinate del luogo che scegli vengono inviate
a Open-Meteo per conoscerne il meteo. L'app non usa mai la posizione del
telefono. Il luogo scelto è salvato solo sul telefono, finché non lo cambi o
disinstalli l'app. Open-Meteo è un servizio meteo indipendente con i propri
termini (open-meteo.com/en/terms).

**Audio del telefono (Music Sync, Android 10 e successivi).** Nelle
Impostazioni puoi far seguire a Music Sync il suono riprodotto dal telefono
stesso invece della stanza. Android chiede allora ogni volta di consentire la
"cattura dello schermo": LumiFX usa questo permesso solo per ricevere il suono
delle altre app, mostra una notifica persistente mentre lo fa e non cattura
mai lo schermo. Quel suono è analizzato in tempo reale come quello del
microfono e non viene mai registrato, salvato o trasmesso. La cattura termina
quando metti in pausa o fermi l'effetto o la chiudi dalla notifica.

**Riproduzione a schermo spento (Android).** Mentre un effetto è in corso
sulle luci, LumiFX può continuare a funzionare a schermo spento. In quel caso
mostra una notifica (da Android 13 il sistema chiede una volta il permesso) e,
durante un effetto Music Sync, continua a usare il microfono esattamente come
descritto sopra. Puoi disattivarlo nelle Impostazioni.

**Schermata di blocco e riproduzione con l'iPhone bloccato.** Mentre un
effetto è in corso sulle luci, gli iPhone con iOS 16.1 o successivi
possono mostrarlo nella schermata di blocco e nella Dynamic Island (una
Live Activity): il nome dell'effetto, la stanza, i suoi colori e un
pulsante Stop, visibili senza sbloccare il telefono. L'app la crea e la
aggiorna sul telefono e non invia nulla a nessuno per mostrarla (non usa
alcun servizio di notifiche push). Gli effetti con suoni o una melodia
continuano a iPhone bloccato, perché iOS lascia un'app attiva in
background finché riproduce un suono; gli effetti senza suoni (Music
Sync compreso) si fermano comunque quando l'iPhone si blocca. Entrambe le cose seguono "Continua a
schermo spento" nelle Impostazioni, e le Live Activity di LumiFX si
possono disattivare anche nelle Impostazioni dell'iPhone.

**Adesivi NFC.** Su Android, quando tocchi "Scrivi su un adesivo" e
avvicini un adesivo NFC al telefono, LumiFX ci scrive un solo link
`lumifx://` e nient'altro: un effetto, una playlist, la nanna o lo stop
e, per un link con una stanza, il nome di quella stanza. Chiunque tocchi
l'adesivo con un telefono può leggere quel link. Quando il tuo telefono
sbloccato tocca un adesivo, Android apre LumiFX con il link che
contiene; LumiFX usa solo quel link e non legge nient'altro
dall'adesivo. Su iPhone LumiFX
non usa l'NFC: è l'app Comandi a leggere l'adesivo e ad aprire il link
che ci hai copiato.

**Luci per le notifiche (Android).** Se scegli delle app e consenti a
LumiFX l'"accesso alle notifiche" nelle impostazioni di Android, Android
avvisa LumiFX ogni volta che un'app pubblica una notifica. LumiFX guarda
solo quale app l'ha pubblicata (il nome del pacchetto, per esempio
`com.whatsapp`) per verificare se è una di quelle che hai scelto; non
legge mai il titolo, il testo né altro contenuto della notifica. Per
un'app scelta invia un comando di lampeggio (quali luci, quale colore)
al tuo Hue Bridge sulla rete locale, anche a LumiFX chiusa. Nulla delle
tue notifiche viene salvato o trasmesso altrove. Per farti scegliere,
l'app elenca le app presenti nel cassetto delle app del telefono; quella
lista è mostrata solo sul telefono. Le impostazioni che servono per far
lampeggiare le luci a LumiFX chiusa (indirizzo e chiave del Bridge, le
luci, le app e i colori scelti) sono salvate solo sul telefono, cifrate
con una chiave custodita nel Keystore di Android. Puoi disattivare le
luci per le notifiche in LumiFX e revocare l'accesso alle notifiche in
qualsiasi momento nelle impostazioni di Android (di solito App › Accesso
speciale per le app › Accesso alle notifiche, su alcuni telefoni
"Notifiche di app e dispositivi") o disinstallando l'app. Android avvisa
che un'app con questo accesso potrebbe leggere tutte le notifiche;
LumiFX non lo fa. Gli iPhone non permettono a nessuna app di vedere le
notifiche, quindi lì la funzione non c'è.

**Condivisione di scene e playlist.** Quando scegli di condividere, la scena
o la playlist viene inserita in un link o codice QR che passi tu. Contiene
solo i nomi, i colori e le impostazioni che hai creato; LumiFX non lo invia
da nessuna parte.

**Routine e scene Hue.** Le routine di sveglia e buonanotte e le scene Hue
salvate sono memorizzate sul tuo Hue Bridge, come quelle create nell'app Hue.

**Preferenze.** Preferiti, effetti recenti, impostazioni di riproduzione,
le stelline e i passi delle routine del mattino e della sera, i nomi dei
bambini, i premi del negozio delle stelle, le scelte del rituale della
nanna e le scene e storie che crei sono salvati solo sul telefono.

## Connessioni di rete

- **Il tuo Bridge Hue** sulla rete Wi-Fi locale (HTTPS e, per gli effetti
  veloci, uno stream DTLS cifrato). Anche le luci per le notifiche gli
  inviano i comandi di lampeggio in HTTPS, e la festa di Halloween ne
  ascolta il flusso di eventi per i movimenti.
- **discovery.meethue.com**, un servizio di Signify (Philips Hue) che aiuta
  a trovare i Bridge sulla rete. La richiesta non contiene dati personali
  oltre a quelli di qualsiasi richiesta web (l'indirizzo IP pubblico). Puoi
  evitarla inserendo a mano l'indirizzo del Bridge.
- **geocoding-api.open-meteo.com** e **api.open-meteo.com**, solo quando
  usi Meteo in luce: il nome della città cercata e le coordinate del luogo
  scelto, come descritto sopra.

L'app non effettua altre connessioni. Non contiene analytics, pubblicità,
segnalazione di crash né alcuna forma di tracciamento.

## Minori

LumiFX non raccoglie dati personali da nessuno, minori compresi. I nomi
dei bambini che aggiungi alle routine restano sul telefono. Meteo in
luce invia a Open-Meteo solo il nome di un luogo e le sue coordinate, mai
qualcosa che identifichi una persona.

## Modifiche

Se questa informativa cambia, la nuova versione sarà pubblicata allo stesso
indirizzo con una nuova data.

## Contatti

Domande sulla privacy: fz1101hub@gmail.com
