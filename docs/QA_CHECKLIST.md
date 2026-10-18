# QA checklist (on a real phone with a Hue Bridge)

Automated tests cover the engine, the Hue client and the screens with fake
bridges. These are the things only a real bridge, real lights and a real
phone can confirm. Run through the list on an internal-testing / TestFlight
build before every store release.

## Pairing

- [ ] First launch: the home shows "Connect your Hue Bridge"; opening it
      finds the bridge within ~5 s (iOS asks for local network access
      first; allow it).
- [ ] Pairing waits for the bridge button, counts down, and succeeds after
      pressing it. Cancelling works. Letting it time out shows the message.
- [ ] Manual IP entry: a wrong address shows "No Hue Bridge found"; the
      right one pairs.
- [ ] Kill the app and reopen it: the bridge is still connected, lights
      and rooms load.
- [ ] Settings › Forget this bridge asks for confirmation and returns to
      the unpaired state.

## Rooms & zones

- [ ] Every room and zone lists the right light count.
- [ ] Switch and brightness slider change the real lights, and the state
      shown matches the Hue app after pull-to-refresh.
- [ ] Every room shows its Hue scenes as chips; tapping one shows it on
      the lights and the chip becomes selected after the refresh.

## Playing effects on a room (REST)

- [ ] Preview only: the virtual lamps animate; no light changes.
- [ ] A room with colour bulbs: Ocean plays smoothly (no stutter, ~10
      updates/s shared across lights); Emerald Trickster shows the golden
      flash and the travelling green.
- [ ] A room with a white-ambiance bulb: it follows brightness and warm/cool
      changes and never stops responding (no rejected commands).
- [ ] A room containing a smart plug: the plug is ignored and the other
      lights play.
- [ ] "Lights to play on": untick a lamp; it stays as it was while the
      others play, also after Stop and Play; the last lamp cannot be
      unticked; the choice survives a restart.
- [ ] Brightness / intensity / speed sliders take effect while playing.
- [ ] Aurora › "Rose & gold" changes the colours at once while playing
      and is still selected after reopening the effect.
- [ ] Halloween: Vampire's Castle on an entertainment area (footsteps
      coming closer, lightning, crimson flash); Trick or Treat on a room.
- [ ] First Play on Thunderstorm shows the "Flashing lights" warning once;
      "Soften flashes" turns the strikes into soft pulses (also as a switch
      in Settings); Ocean never shows the warning.
- [ ] Pause then Play resumes without a jump; Stop puts every light back
      to its previous colour and brightness within ~2 s (check against
      the Hue app). Turn "Restore lights" off in Settings and check they
      stay as the effect left them.
- [ ] Lock the phone while playing: the effect stops cleanly and lights
      are restored; unlocking shows the Play button.
- [ ] Sleep timer: set 15 min on Fireplace; the button shows the minutes
      left; at the end the effect fades over ~20 s and the lights switch
      off (not back to their previous state), on a room and on an
      entertainment area alike.
- [ ] Screen stays on while an effect plays.

## Entertainment streaming

- [ ] Settings › Entertainment streaming › New area: capable lights are
      listed, plugs are not; drag lights on the map; Save creates the area
      (visible in the Hue app too).
- [ ] Edit an area: positions come back where they were saved; Delete asks
      for confirmation.
- [ ] Player › choose the area: Thunderstorm shows crisp lightning strikes
      on the chosen lights; Disco pulses sharply on the beat; no visible
      lag or dropped frames.
- [ ] Leave the player while streaming: the area is released (the Hue
      app no longer shows it as in use).
- [ ] Start streaming from the Hue app (or Hue Sync) to the same area while
      LumiFX plays: LumiFX stops and shows "Streaming stopped by the
      bridge".
- [ ] Pause while streaming: lights hold the last frame and the stream
      stays open; Play resumes.

## Music Sync

- [ ] First start asks for microphone permission with the explanatory text.
      Deny it: the message explains and nothing plays. Allow it in system
      settings and try again.
- [ ] With music playing in the room: the beat light blinks on the beat,
      the BPM is roughly right after a few seconds, Beat Pulse flashes on
      beats, Spectrum shows bass on the left lights.
- [ ] Quiet room: the lights stay near the dim floor, no random flashes.
- [ ] Sensitivity slider changes the response.
- [ ] Pause releases the microphone (the system indicator disappears).
- [ ] Music playing from Spotify/Apple Music on the same phone keeps
      playing when Music Sync starts (no pause, no volume drop), on both
      platforms, with the phone speaker and with a Bluetooth speaker (the
      speaker must stay in high-quality A2DP, not switch to the call
      profile).
- [ ] A phone call during Music Sync: on iOS the lights follow the music
      again by themselves after the call; on Android the capture continues.
      If the microphone is lost for good (another app takes it), the app
      says so and Stop then Play recovers.

### Music Sync, phone audio (Android 10+ only; not yet verified on a device)

- [ ] Settings shows "Music Sync source" on Android 10+ and not on iOS or
      Android 9.
- [ ] Choose "This phone's audio", play Beat Pulse: Android's "Start
      recording or casting?" dialog appears; Cancel shows the explanation
      and nothing plays; Start now shows the "Music Sync is on"
      notification and the lights follow YouTube / a local music file /
      a game played on the phone, with the phone speaker, wired and
      Bluetooth headphones.
- [ ] Spotify and other apps that block capture: the lights stay at the
      dim floor (expected: Android does not let LumiFX hear them); the
      microphone source works for them.
- [ ] Pause and Stop remove the notification; ending it from the system
      (the cast/record chip in the status bar) shows the "capture stopped"
      message, and Stop then Play asks for consent again.
- [ ] On Android 14+, the consent is asked on every Play (Android no
      longer reuses it).
- [ ] Switching the source in Settings while an effect plays moves to the
      new source without stopping the lights.
- [ ] Notification is in the phone's language (eight languages). On
      Android 13+ it is only visible when LumiFX may post notifications
      (the app never asks for that; the capture works either way).

## Network edge cases

- [ ] Wi-Fi off: the home banner says the bridge is not reachable; Retry
      works after turning Wi-Fi on.
- [ ] Change the bridge's IP address (router DHCP reservation or reboot):
      the app finds it again by itself on the next refresh.
- [ ] Bridge with an old firmware (no CLIP v2): the message asks for an
      update.

## Home-screen shortcuts

- [ ] Long-press the app icon (Android) / 3D-touch it (iOS): the
      favourites appear as shortcuts (the recently played effects when
      there are no favourites), in the phone's language; tapping one
      opens the player for that effect, both with the app closed and
      with it in the background.

## Continuous playback, playlists, own scenes

- [ ] Play Ocean on a room, go back to the home: the mini-player shows
      Ocean and the room; pause, stop and opening the player from it work.
- [ ] Open Sunset while Ocean plays: the note says Ocean plays; Play
      cross-fades the real lights to Sunset (no flash back to the original
      colours in between).
- [ ] A playlist of three effects at 1 minute each moves on by itself,
      pauses its clock while paused, and the skip button works. Shuffle
      never repeats an effect twice in a row.
- [ ] Make a scene of your own with four colours and Flickering: the
      preview and the real lights match; edit it while it plays and the
      lights follow; delete it and it disappears from favourites and
      playlists.
- [ ] Save as Hue scene while Aurora plays on a room: the scene appears in
      the Hue app and in Rooms & zones, and recalling it from the Hue app
      shows the same colours.
- [ ] Lock the phone while a playlist plays: playback stops cleanly, as
      for a single effect.

## Screen off, routines, sharing, gradients, night light

- [ ] Android: play Ocean on a room and lock the phone: the lights keep
      moving for at least 10 minutes; the notification names the effect and
      room; its Stop stops the effect and puts the lights back. Android 13+
      asks once for notification access. Music Sync (microphone) keeps
      reacting with the screen off. Settings › "Keep playing with the
      screen off" off: locking stops the effect again.
- [ ] Save Aurora as a Hue scene with "Keep moving": recalled from the Hue
      app (and from Rooms & zones) it drifts through Aurora's colours.
- [ ] Wake-up & bedtime: create a wake-up for 3 minutes from now with a
      5 minute fade and sunrise colours: the lights brighten by themselves
      with the phone off; it appears in the Hue app's automations. Same for
      a bedtime routine (the go-to-sleep configuration is untested on a real
      bridge: if the bridge refuses it, note the error shown). Switching a
      routine off and deleting it work in both apps.
- [ ] Share a scene by QR code: another phone's camera opens LumiFX, which
      asks, then adds it; a playlist brings its scenes along; "Share or back
      up" in Settings restores everything on a fresh install.
- [ ] A gradient lightstrip in a room: Ocean and Party Chase move along the
      strip; stopping brings back the gradient it had.
- [ ] Night light: soft glows full screen, screen stays on, close returns
      to the player; with the effect playing on lights they follow the lights.
- [ ] Between 1 Oct and 2 Nov the home starts with "Halloween is coming";
      between 20 Nov and 6 Jan with "Christmas time".

## This round: sounds, rooms, stories, TV

- [ ] Gentle start: with lights on in warm white, play Ocean: they glide
      into the blues over a couple of seconds instead of jumping. Settings
      can turn it off.
- [ ] Sounds: Fireplace crackles, Ocean has waves, Thunderstorm answers
      lightning with thunder; the volume slider and the switch work; sound
      pauses, switches and stops with the effect; music in another app
      keeps playing underneath (iOS mixes with it, Android without audio
      focus).
- [ ] Several rooms: choose two rooms in "Play on › Several rooms": both
      play, a light in both rooms plays once, stopping restores both.
- [ ] Search: the search icon finds "drago" (Italian) and "Kraken"; the
      kind and collection chips narrow the list.
- [ ] Wall panel on a tablet: time, favourites and every room with its
      switch, brightness and Hue scenes; after two minutes it dims; the
      first touch only wakes it; the screen never locks while it is open.
- [ ] Read-along: Emerald Trickster shows its words, the line changes with
      the golden spark, the switch hides them; TalkBack / VoiceOver read
      each new line.
- [ ] Story editor: Stories › New story, three moments (words only at
      0:00, a spark at 0:05 with words, footsteps at 0:20), save: it is
      first under "My stories", plays on the lights with its words, can be
      added to a playlist, shared by QR to another phone, edited while
      playing (the lights change at once) and deleted.
- [ ] TV Sync (real TV needed): Interactive › TV Sync › Play asks for the
      camera once with the purpose text; with the phone on a table facing
      the TV, the lights take the TV's colours left to right within a
      fraction of a second, on a room and on an entertainment area. Try
      the phone in portrait and in landscape: left stays left. Pause turns
      the camera off (the system indicator disappears); leaving the app
      stops TV Sync and puts the lights back. Refusing the camera shows the
      explanation and nothing plays.

## This round: bedtime, schedules, buttons, voice, holidays

- [ ] Bedtime: Home › Bedtime with Silent Snowfall, 5 min story, 5 min
      glow: the story plays dimmer with its words, after 5 minutes it
      cross-fades to Goodnight Glow, after 10 the lights fade out and stay
      off. The next time the same choices are already set.
- [ ] Schedule: play Ocean on a room, Schedule › in 3 minutes, today only,
      switch off 2 minutes later. With the phone locked the room turns on
      in Ocean's colours and keeps moving (if it stays still, note it: the
      scene is recalled through the bridge's older API), then switches
      off. Wake-up & bedtime lists it; the switch pauses it; delete removes
      it and its scene from the Hue app.
- [ ] Hue buttons: give a dimmer's button 1 Aurora and button 4 Stop, set
      them to do nothing in the Hue app. A short press plays Aurora, again
      stops it; button 4 stops anything. Works with the screen off while an
      effect plays (Android); after reopening the app it still works.
- [ ] Siri (iOS 16+): "Play Fireplace in LumiFX", in Italian "Avvia Camino
      con LumiFX", "Start bedtime in LumiFX", "Stop LumiFX". The phrases
      appear in the Shortcuts app under LumiFX.
- [ ] Google Assistant (Android, app installed from Play internal testing):
      "Open Fireplace in LumiFX", "Apri nanna su LumiFX". If the Assistant
      opens only the app, App Actions may need the app on Play first.
- [ ] Holiday shelves: set the phone's date to 30 Dec (Happy New Year),
      10 Feb (Valentine's Day), the week before Carnival and the week before
      Easter: each shows its story first; nothing in them flashes.

## This round: wake-up light, timers, read aloud, photos, parties, weather

- [ ] Ok-to-wake: Wake-up & bedtime › New ok-to-wake light on a bedroom,
      night glow in 2 minutes, green 3 minutes later, off after 5: with the
      phone off the room turns dim amber, then green, then off. The switch
      pauses it; delete removes its schedules from the bridge.
- [ ] Light timers: Teeth (2 min) on a room: the lamps turn from blue to
      purple one after the other, then a little party and the lights go
      back as they were. Cooking with 5 minutes ends with three soft
      flashes. Leaving the timer screen, the mini player keeps counting.
- [ ] Read aloud: in a story's player switch on Read aloud; each line is
      spoken in the app language as it appears, a little slowly; pause
      stops the voice, resume does not repeat the line. Try Italian and
      Japanese (the voice must be installed on the phone). Music from
      another app keeps playing (iOS mixes, Android queues).
- [ ] Scene from a photo: New scene › From a photo › Choose a photo (iOS
      asks for photos the first time; Android shows its photo picker) and
      Take a photo: the colours change to the photo's; a black-and-white
      photo gives warm whites. Deny the permission: a message explains it.
- [ ] Birthday: Parties and games › Birthday party, name and age 6: six
      sparks light up the candles, the room flickers warm; "Blow out the
      candles" darkens the room for a breath, then confetti and a rainbow
      for 30 s. Again with "Blow on the phone": blowing firmly on the
      microphone blows them out, talking or singing "Happy birthday" does
      not. With Read aloud on, the greeting is spoken with the name.
- [ ] Games: each game for a minute on a room. Red light, green light:
      green, a second of amber, red, random lengths; the phone shows the
      call in big letters. Statues: dancing colours, then icy blue.
      Colour hunt: the colour fills the room, then the lamps go out one by
      one in 10 s. With "Say the calls out loud" the calls are spoken.
- [ ] Weather lights: type your city, pick it, check now and tomorrow
      against a weather site; "Show on the lights" on both. In flight
      mode the screen says it cannot get the weather and Retry works once
      back online. Phone language Italian: city names in Italian. In the
      US region temperatures are in °F.

## This round: games, calm, kids mode, voices, around the house

- [ ] Choose your path: Stories › Choose your path › The Lost Star: the
      buttons appear when the part's words end, the lights keep glowing
      meanwhile; each of the four endings plays once and the lights go
      back. With Read aloud on, the words are spoken.
- [ ] Light memory: the lamps flash each colour clearly (on a room and
      on an entertainment area); a tap lights the lamps at once. Note any
      lag between tap and lamp on REST (rooms).
- [ ] Calm breathing: 1 minute of square breathing; lamps rise for 4 s,
      hold, fall, hold, in step with the circle; the voice guides if on.
- [ ] Pomodoro with 2 rounds: focus colours, three soft flashes at the
      break, greens, then the second round and the party at the end.
- [ ] Advent calendar: set the date to 5 December: doors 1–5 open, 6 says
      when; each surprise plays once. In January after the 6th all lock.
- [ ] How many sleeps: add a countdown a week ahead; the lamps show seven
      golden sparks; on the day, a party.
- [ ] Kids mode: choose four effects, start; back gesture and the
      Android back button do nothing; no mini-player; close and reopen
      the app: still in kids mode; leave with the sum. Try a lumifx://
      link while locked: the effect plays, the screen stays.
- [ ] Your voice: record two lines of a story of your own (iOS asks for
      the microphone), listen, re-record one; play the story with Read
      aloud off: your voice, in time; delete the story: recordings gone.
- [ ] Away mode on two rooms, 2 minutes from now, off 5 minutes later:
      the rooms come on within the random 30 minutes, one 15 minutes
      after the other, and go off; the Hue app shows nothing odd. Pause
      and delete from LumiFX.
- [ ] Night path with a Hue motion sensor (set to do nothing at night in
      the Hue app): at night, walking past turns the room dim amber; it
      goes off 2 minutes after the last movement. Daytime: nothing.
- [ ] Natural light in a room: the Hue app shows the five scenes and the
      smart scene; switched on, the room shows the white of the hour and
      moves on at the next time slot. Delete removes all of them.

## This round: routines, music, stories, games, cinema, NFC, notifications, lock screen

- [ ] Home: the experience cards, then the groups For the family, More
      and (with a bridge) Your home; each new entry below is where this
      list says.
- [ ] Morning and evening (For the family): Choose the steps, untick two
      morning steps; Start shows only the kept pictures. Each tap flashes
      the step's colour and one more lamp fills up; a second tap undoes
      it. The last step plays a party and earns a star; doing it again the
      same day says the star is already yours. The chart shows the last
      seven days (set the date forward a day: a new star can be earned).
- [ ] Lullabies (For the family) on a room: Brahms's Lullaby, 3 times,
      "Then fade out the lights" on: the music box plays from the phone,
      each note lights a lamp (low notes at one end of the room, high at
      the other), three times through, then the lights fade out and stay
      off. Twinkle Twinkle once with the switch off: the lights go back as
      they were. With Settings › Sounds off the screen offers to turn them
      on. Note any lag between notes and lamps on a room (REST) compared
      with an entertainment area.
- [ ] Christmas light show (Parties and games): Jingle Bells, Silent
      Night and We Wish You a Merry Christmas each play once on little
      bells, every note a lamp in red, green or gold over a festive glow.
- [ ] Story maker (For the family, and the card above the Stories list):
      Dragon, Under the sea, A treasure map, name "Sam": five lines in
      turn, each with its lights, then a warm glow that fades; with Read
      aloud on each line is spoken with the name. "Surprise me" changes
      hero, place and adventure and keeps the typed name. In Italian,
      German, French, Spanish and Portuguese read the lines with a girl's
      and a boy's name: nothing in them depends on the hero's gender.
      With the router's internet unplugged it works the same.
- [ ] Count the lights (Parties and games) on a room: the lamps and the
      lamp on screen blink 1 to 3 times in colours, slowly enough to count
      aloud; the right number flashes gold and, with sounds on, the phone
      says it; three right in a row add a number, up to 9; a wrong answer
      shows the same blinks again.
- [ ] Colours in another language: choose Français; a colour turns the
      room that colour and the phone says "rouge"; Quiz: hear a word and
      tap it among four, a wrong tap says it again. Try Japanese and
      Dutch (the voice must be installed on the phone). With sounds off
      the screen says so.
- [ ] Monster spray (For the family): the room goes dim purple with a
      green glint now and then; each Spray! flashes the lamps and one of
      the five monsters goes; then the guardian light, warm and low, set
      to 15 minutes, fades out and switches off at the end. Changing the
      minutes while it is on starts the time again.
- [ ] Cinema mode (More) with "Soft glow during the film" on: Start the
      film dims the room over ~30 s to a faint cool glow; Intermission
      rises in a few seconds to a warm half light; Back to the film dims
      again; End of the film brings the lights back over ~45 s, then the
      room has the colours it had before. Again with the glow off: dark.
      Left on the intermission, after 20 minutes the room goes back by
      itself. Android: lock the phone during the film, the lights stay
      dim. iPhone: the screen stays on; locking it stops the film and the
      lights come back (no sound, as for any silent effect).
- [ ] NFC stickers, Android (More › NFC stickers, NFC on): Write on a
      sticker for Play Fireplace with a blank NTAG213: "Sticker ready".
      With the phone unlocked and LumiFX closed, touch the sticker:
      LumiFX opens and plays Fireplace; the same with LumiFX open on
      another screen. A Start bedtime sticker starts bedtime, a Stop one
      stops and puts the lights back; a playlist sticker plays it.
      Touching with the screen locked does nothing (Android reads NFC
      only when unlocked).
- [ ] NFC edge cases: a locked (read-only) sticker says it is locked; a
      long playlist link on a small sticker says it does not fit; a bank
      or transit card says it cannot hold links; pulling the sticker away
      mid-write says to try again; Cancel stops waiting. NFC off: the
      card says so and Turn on opens the settings, coming back the write
      buttons appear. A phone without NFC explains it and still copies
      links.
- [ ] NFC on iPhone (XS or later): the screen explains the Shortcuts
      app and has no write button. Copy Play Fireplace; Shortcuts ›
      Automation › New Automation › NFC › Scan the sticker › Open URLs
      with the copied link (Run Immediately): touching the sticker opens
      LumiFX and plays Fireplace. Settings › Shortcuts and automations
      lists Start bedtime too.
- [ ] Notification lights, Android (Your home › Notification lights):
      the card says LumiFX only sees which app posted. Allow opens
      Android's notification access page for LumiFX (the list on Android
      10 and older); allow it, accept Android's warning, come back: the
      Allow card is gone. Add a messaging app in green and an e-mail app
      in blue (only launcher apps are listed; search works), choose a
      room; Try it flashes the room (colour lights blink in the colour,
      white lights on and off) and then puts it back.
- [ ] Send a message from another phone: the room flashes green for ~3
      s, then goes back as it was. Three messages within 15 s flash once.
      A music player's ongoing notification, a download in progress and
      an app that was not chosen flash nothing.
- [ ] App closed: swipe LumiFX away from the recent apps, and once after
      restarting the phone: a message still flashes the lights. On phones
      with aggressive battery savers (Xiaomi, Huawei, Samsung's sleeping
      apps) note whether it stops after a while.
- [ ] Quiet hours: set them from now to two minutes later: a message
      inside flashes nothing, one after flashes again. The default
      22:00–07:00 crosses midnight. Quiet hours off: always flashes.
- [ ] Revoke notification access in Android's settings: the screen
      shows Allow again and nothing flashes. The main switch off, or the
      bridge forgotten: nothing flashes. After the bridge changes IP
      address and the app finds it again, flashes work again. A light
      without signalling (an older bulb) breathes instead.
- [ ] iPhone: no Notification lights entry anywhere.
- [ ] Lock screen, iPhone (iOS 16.1+, the widget extension added as in
      `docs/IOS_WIDGET.md`, Settings › "Keep playing with the screen off"
      on, with the iOS text): play Fireplace on a room: the lock screen
      shows Fireplace, the room, its colours and Stop; on an iPhone with
      a Dynamic Island the bulb shows there and a long press shows the
      colours and Stop. Pause in the app: the icon changes; switch to
      Ocean: name and colours update; Stop in the app: it goes away.
- [ ] The lock screen's Stop opens LumiFX (after Face ID or the code),
      which stops the effect and puts the lights back; the Live Activity
      goes away. Preview only (no room): none. Live Activities off for
      LumiFX in iOS Settings, or "Keep playing with the screen off" off:
      none, and playing still works.
- [ ] Locked with sound, iPhone: Lullabies (Brahms, 3 times, fade out)
      on a room with the silent switch on, then lock the phone: the music
      box is heard, the notes keep lighting the lamps to the end and the
      lights fade out. Fireplace with sounds keeps crackling and moving
      for 10 minutes locked; music from another app keeps playing with
      it.
- [ ] Locked without sound, iPhone: Aurora (no sounds), or Fireplace
      with Settings › Sounds off, then lock the phone: the effect stops,
      the lights go back and the Live Activity goes away.
- [ ] Kids mode with two chosen effects: a link, an NFC sticker, a Siri
      phrase or a Hue button for one of them plays it; one for another
      effect or a playlist does nothing; Stop and Start bedtime still
      work.
- [ ] Mini-player: start a light timer, a game, a birthday, the story
      maker, a lullaby, the monster spray, cinema mode, a routine and a
      learning game in turn, go back to the home: the mini-player opens
      that feature's own screen, where it is, not the player.

## This round: Morse, hot and cold, piano, profiles, star shop, ritual, Halloween, quick tiles

- [ ] Links to screens: write `lumifx://app/go/ritual` on an NFC sticker
      (NFC stickers › Open the bedtime ritual); touching it opens the
      ritual once (touching again does not stack a second one); in kids
      mode nothing opens. Also `/go/piano`, `/go/star-shop` from an
      automation app.
- [ ] Piano: Record, play five notes with pauses, Stop recording, Play
      it back: the same notes and the same pauses, the same lamps flash.
      Learn a song cancels a recording.
- [ ] Morse › Guess: Flash a letter (the lamps flash one letter), a wrong
      choice says Try again, Flash it again repeats the same letter, the
      right one shows Well done with the code; a new letter each time.
- [ ] Routines › Choose the steps › Add a step "Feed the cat" with a
      picture and colour: it is ticked for that routine, shows in the
      routine with its picture and fills a lamp; untick it; delete it:
      gone from every routine.
- [ ] Story maker › at the end, Save to My stories: it appears under
      Stories › My stories with the same words read along and plays
      again; editable in the story editor.
- [ ] Home: For the family starts with Bedtime ritual; Parties and games
      lists Secret messages, Hot and cold, Light piano and Halloween
      party.
- [ ] Count the lights: answer four right: the score shows "New
      record!"; leave and reopen (and once after restarting the app):
      "Best: 4"; a worse game leaves it. Colours in another language
      (phone not in Dutch): choose Nederlands, leave, restart the app:
      Nederlands is chosen.
- [ ] Notification lights with TalkBack: each colour dot is read by its
      name in the phone's language ("green", "verde"…) and as selected.
- [ ] Quick Settings tiles (Android): open the quick settings panel ›
      edit (pencil), drag "Stop effect" and "Bedtime" in; with the phone
      in Italian they read "Ferma effetto" and "Nanna", in Japanese
      "エフェクト停止" and "おやすみ". Play Ocean on a room, unlocked:
      Stop effect closes the panel, opens LumiFX, stops it and puts the
      lights back. Bedtime starts bedtime with the last choices. Both with
      LumiFX swiped away from the recent apps too.
- [ ] Tiles on a locked phone (PIN or fingerprint set): tapping one asks
      to unlock first, then acts; cancelling the unlock does nothing. Try
      Android 14+ and an older version (the tile opens the app in two
      different ways). In kids mode both tiles still work.
- [ ] Secret messages (Parties and games) on a room, "SOS" in white:
      after a breath the lamps flash three short, three long, three
      short; a dash (~1 s) is clearly longer than a dot (~0.35 s), and
      the pauses between letters and words are visible. The letter being
      sent is lit up on screen with its code. Someone who did not see the
      typing decodes "HI MUM" from the lamps with the alphabet table.
      Note whether short gaps blur on a room (REST) compared with an
      entertainment area. "Café!" sends CAFE; the field stops at 30
      characters; red and blue work as colours.
- [ ] Hot and cold on a room: it starts cold (light blue); eight taps
      on Warmer go through pale blue and yellow to orange and red, each
      step brighter and livelier; the phone speaks only when the word
      changes (Warm, Hot!, Boiling!), not on every tap; Colder down to
      deep blue says "Freezing!". In Italian: "Acqua", "Fuochino",
      "Fuoco!". Settings › Sounds off: no voice, the lights still change.
      Found it! says so and throws confetti of light for ~8 s.
- [ ] Light piano on a room: each key's note sounds at once on the phone
      (note any delay you can hear) and only one lamp flashes, in the
      key's colour: the low C at one end of the room, the high C at the
      other. Quick taps ring on together. Compare the lamp's lag on a
      room (REST) with an entertainment area. Sounds off: no notes, the
      screen offers to turn sounds on, the lamps still flash.
- [ ] Piano › Learn a song › Twinkle Twinkle: the key to play glows; a
      wrong key does not move on; the last note shows "Bravo!". Key names:
      Italian, Spanish and Portuguese Do Re Mi, French Ré, Japanese ドレミ,
      German C D E F G A H C, English and Dutch letters.
- [ ] Child profiles, on a phone updated from the previous build with
      stars and chosen routine steps: Morning and evening still shows
      those stars and only "Add a child". Add "Sam": Sam has the old
      stars and steps. Add "Alex": no stars, all steps; earn a star and
      untick a step for Alex; back to Sam: unchanged. Restart the app:
      the chosen child is still selected. The pencil renames; removing
      Alex asks first and Alex's stars and steps are gone. At six children
      Add disappears. The story maker shows the names as chips; a tap
      fills the hero's name.
- [ ] Star shop (Morning and evening › Star shop): Add a reward asks
      "To go on, type the result of a + b." (not the kids mode words); a
      wrong sum is refused. Add "Ice cream" with a picture, 3 stars. With
      fewer stars the reward says how many more; with enough, Get it asks
      the sum, then the lamps throw a short gold party and only the
      active child's balance drops by 3. A long press removes a reward
      after the sum. Leaving kids mode still asks with its own words.
- [ ] Bedtime ritual, all five steps, Brahms, 15 minutes, a child
      chosen: Start opens the evening routine; finishing it or going back
      continues with the monster spray; closing that plays tonight's
      story with the child's name as hero; when it ends the lullaby plays
      once, then the guardian light fades out over 15 minutes and the
      lights switch off. The monster spray's own guardian timer does not
      cut the story short. Next step skips any step. With only one step
      kept, it cannot be unticked; the choices come back next time.
- [ ] Halloween party with a real Hue motion sensor (set to do nothing
      in the Hue app for the test): the sensor is listed; Start the party
      turns the room dim purple, green and midnight blue with a faint
      green glint now and then. Walk past: within a second or two the
      lamps flash white then green, the phone thunders (sounds on) and
      red eyes glow on one lamp. Walk past again at once: nothing; after
      15 s: another scare. Scare now works at any time.
- [ ] Halloween party edge cases: unplug the bridge for 30 s, plug it
      back: scares on motion come back by themselves. Leave the screen:
      walking past does nothing. Without a motion sensor: the screen says
      none was found and Scare now still works. Nothing flashes fast and
      no flashing warning appears.
- [ ] Mini-player: start Secret messages, Hot and cold, the piano and
      the Halloween party in turn and go back to the home: the
      mini-player opens each one's own screen.

## This round: kids mode games, colour mixing, nap light, more tunes and tales, links

- [ ] Kids mode setup › "Also offer these games": all four ticked at
      first; untick Counting. Start kids mode: big buttons for the light
      piano, colour words and colour mixing above the effects, no
      Counting. Open the piano, play a few keys: no mini-player appears;
      back returns to kids mode, and back again does nothing.
- [ ] Colour mixing (Fun › Colour mixing) on a room: tap yellow; white
      fades (it makes no colour with yellow); tap blue: the lamps glow
      yellow and blue, go dark for a moment, then shine green, over and
      over; "yellow + blue = green" on a green card and the phone says
      "green" (sounds on). In Italian the words are in Italian.
- [ ] Colour mixing quiz: "What do red and white make?" with three
      colours; a wrong one says Try again, the right one plays the mix
      and a new pair comes after a few seconds. Back to the home: the
      mini-player opens Colour mixing.
- [ ] Nap light (For the family): 20 min, Start the nap: the lamps glow
      a faint amber; the screen shows "Green in 20 minutes" counting
      down. After 20 minutes the lamps turn slowly green (about 20 s, no
      flash) and the screen says "Green: time to get up!"; 20 minutes
      later the lamps go back to how they were. Stop ends it at any time.
- [ ] Lullabies: Au clair de la lune is in the list and plays with its
      lights. Light piano › Learn a song: Hot Cross Buns first, then
      Twinkle, Mary Had a Little Lamb, Frère Jacques, Ode to Joy.
- [ ] Story maker: the penguin, the turtle, the jungle, the little
      island, the lost teddy and the sleepy moon are offered; a story with
      each reads well in Italian and Japanese, never depending on the
      hero's gender.
- [ ] Links: `lumifx://app/go/colour-mixing`, `/go/nap`, `/go/morse`,
      `/go/timers` (and the others in the README) open their screens from
      an NFC sticker; in kids mode they do nothing.


## This round: noise light, a tune for teeth, festivals, search

- [ ] Noise light (Parties and games) on a room, Indoor voices, Start
      listening: allow the microphone; the lamps turn green. Talk
      normally: green; shout for a second or two: amber, then red ("Too
      loud!", "Too loud once"); quiet for a few seconds: back to green.
      One clap alone changes nothing. Quiet turns amber sooner, Playtime
      later.
- [ ] Noise light: Stop, or leave the screen: the microphone indicator
      (iOS orange dot / Android green chip) goes away and the lamps go
      back. Deny the microphone: a message says how to allow it.
- [ ] Light timers › Brush your teeth with "A tune while brushing" on and
      sounds on: Twinkle Twinkle plays on the music box for the two
      minutes while the lights count down; switched off: silent.
- [ ] Set the phone's date to 6 November 2026: the home shows "Happy
      Diwali" with Festival of Lights. 5 December 2026: "Happy Hanukkah"
      with Eight Little Lights above "Christmas time". 15 February 2026:
      "Happy Lunar New Year" above "Valentine's Day". Each story reads
      along and aloud in Italian and Japanese and flashes nothing fast.
- [ ] Siri: "Play Eight Little Lights in LumiFX" (and the Italian name in
      Italian) starts it.
- [ ] Search: type "storm": Thunderstorm shows right under the filters;
      the collections scroll sideways in one row.

## This round: remembered choices, more kids games, breathing at bedtime, Repeat after me

- [ ] Nap light: choose 90 min, go back, open it again: 90 min is
      chosen. Noise light: choose Quiet, leave, come back: Quiet. Light
      timers: switch the teeth tune off, leave, come back: still off.
- [ ] Kids mode setup offers six games (piano, counting, colour words,
      colour mixing, light memory, calm breathing); in kids mode they sit
      in one row that scrolls sideways above the effects; each opens and
      leads only back to kids mode.
- [ ] Bedtime ritual with every step: after the monster spray, "Calm
      breathing" (step 3 of 6): the lamps rise and fall for a minute with
      "Smell the flower… / Blow out the candle…" read along; then the
      story. Unticking Calm breathing skips it. The home subtitle names
      the breathing step.
- [ ] Play a lullaby with "Switch off" on, then start a 20 min nap
      light: the lamps stay amber past the lullaby's length and turn
      green at 20 minutes. Same with the noise light: it keeps going.
- [ ] Noise light while listening: lock the phone or switch apps: the
      microphone indicator goes away and the lamps go back; start an
      effect with a Hue button: the noise light stops listening. No
      mini-player shows on the noise light screen.
- [ ] Light piano › Repeat after me: "Listen…", three notes play with
      their key glowing and lamp flashing; keys tapped meanwhile do
      nothing; "Your turn!": play them back: "Bravo! One more note", then
      a tune of 4 notes; a wrong key: "Oops! Listen again" and the same
      tune plays again. On a phone the keys stay big in every mode; the
      songs to learn scroll sideways.

## This round: teeth timer in the routines, goodnight by name, best tune

- [ ] Morning and evening › Start the morning routine: "Brush your teeth"
      has a timer button; tap it: the two-minute light timer runs (with
      Twinkle if the teeth tune is on). Let it finish and close: the step
      is ticked and the timer button is gone. Stop it early instead: the
      routine's lamps come back and the step is not ticked.
- [ ] Bedtime ritual with a child "Mia" chosen and read aloud on: at the
      guardian light the screen says "Goodnight, Mia!" and the phone says
      it; with no child: "Goodnight!"; read aloud off: nothing is said.
- [ ] Light piano › Repeat after me: after a tune of 3 notes, "Best: 3
      notes" shows next to the length, and stays after leaving and coming
      back.

## Links and widget

- [ ] Settings › Shortcuts and automations: copy "Play Fireplace", paste it
      into Safari / Chrome: LumiFX opens and plays it. Same from a Siri
      Shortcut (iOS, "Open URL") and an Android routine or Tasker.
- [ ] The room link variant plays in that room; /stop puts the lights back.
- [ ] A link to Thunderstorm before the flashing warning was ever shown
      only opens the player.
- [ ] Android: add the LumiFX widget; it shows "Star effects…" until a
      favourite exists, then up to four tiles in the effects' colours (grey
      before Android 12); a tile plays its effect, with the app closed and
      in the background; the title opens the app.

## Accessibility and first launch

- [ ] TalkBack / VoiceOver: the home, a list, the player (lamp preview read
      as one description, sliders as percentages), the mini-player and the
      scene editor can all be used without looking.
- [ ] Reduce Motion (iOS) / Remove animations (Android): Settings shows
      "Soften flashes" always on; Thunderstorm's lightning is soft.
- [ ] Fresh install: the three welcome pages show once; "Connect now"
      pairs and finishes; reinstalling over an existing install with data
      (an update) does not show them.

## iPad and tablets

- [ ] On an iPad (or a 10" Android tablet) in portrait: the home shows
      the three experience tiles side by side, Stories is a grid of two
      or three columns, and the player has the setup on the left and the
      lamps, buttons and sliders on the right.
- [ ] Rotate to landscape and back: nothing overflows, the selected
      target and lights are kept.
- [ ] iPad Split View at a third of the screen: the phone layouts come
      back and remain usable.
- [ ] Largest accessibility font size: the home tiles and the effect
      grid grow with the text and nothing is cut off.

## Store builds

- [ ] App icon and splash look right on both platforms (adaptive icon on
      Android 13+, dark and light system themes).
- [ ] Version shown in Play Console / App Store Connect matches
      `pubspec.yaml`.
- [ ] Android bundle is signed with the upload key (Play Console shows no
      "debug key" warning).
