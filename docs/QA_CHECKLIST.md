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
      keeps playing underneath (iOS ambient, Android without audio focus).
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
