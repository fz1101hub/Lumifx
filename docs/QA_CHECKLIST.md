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

## Playing effects on a room (REST)

- [ ] Preview only: the virtual lamps animate; no light changes.
- [ ] A room with colour bulbs: Ocean plays smoothly (no stutter, ~10
      updates/s shared across lights); Emerald Trickster shows the golden
      flash and the travelling green.
- [ ] A room with a white-ambiance bulb: it follows brightness and warm/cool
      changes and never stops responding (no rejected commands).
- [ ] A room containing a smart plug: the plug is ignored and the other
      lights play.
- [ ] Brightness / intensity / speed sliders take effect while playing.
- [ ] Pause then Play resumes without a jump; Stop puts every light back
      to its previous colour and brightness within ~2 s (check against
      the Hue app). Turn "Restore lights" off in Settings and check they
      stay as the effect left them.
- [ ] Lock the phone while playing: the effect stops cleanly and lights
      are restored; unlocking shows the Play button.
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

## Network edge cases

- [ ] Wi-Fi off: the home banner says the bridge is not reachable; Retry
      works after turning Wi-Fi on.
- [ ] Change the bridge's IP address (router DHCP reservation or reboot):
      the app finds it again by itself on the next refresh.
- [ ] Bridge with an old firmware (no CLIP v2): the message asks for an
      update.

## Store builds

- [ ] App icon and splash look right on both platforms (adaptive icon on
      Android 13+, dark and light system themes).
- [ ] Version shown in Play Console / App Store Connect matches
      `pubspec.yaml`.
- [ ] Android bundle is signed with the upload key (Play Console shows no
      "debug key" warning).
