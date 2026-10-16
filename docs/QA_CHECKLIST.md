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
- [ ] Notification is in the phone's language (six languages).

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
