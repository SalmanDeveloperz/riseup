# Screens #19 Sleep sounds · #20 Now Playing · Bedtime reminder: brief & review guide

**Phase 6** · on `development`

## What they do
- **Sleep sounds (#19):** the Sleep tab. 10 sounds in 3 groups: **Nature** (Rain, Ocean, Stream, Wind, Night),
  **Cozy** (Fireplace, Fan) and **Noise** (White, Pink, Brown). Tap to mix **up to 3** at once. A 4th tap shows a hint.
  A **mini player** sits at the bottom (mix name, Play/Pause). When nothing plays, **"Play last mix"** brings back
  last night's sounds at their volumes.
- **Now Playing (#20):** tap the mini player. A big Play/Pause, **sleep timer** chips (15/30/45/60/90 min) with a
  countdown ring, a **volume slider** per sound (✕ removes it), and **Stop all sounds**. Closing the sheet does NOT
  stop the music.
- **Bedtime reminder:** a card at the bottom of the Sleep tab. Switch it on → iOS asks for notification permission
  (first time only) → a daily "Time to wind down 🌙" notification at the chosen time (default 10:30 PM).

The sounds keep playing with the phone **locked**, show **Play/Pause on the lock screen** ("Now Playing"), fade out
gently at the end of the timer, and **stop by themselves when an alarm rings**.

## Connection map
```
AppDependencies.live()
  ├─ sleepSounds: SleepSoundPlayer()            ← ONE long-lived mixer for the whole app
  └─ bedtimeReminder: NotificationBedtimeReminder()

ScreenFactory.makeRoot(.sleep) → SleepView(SleepViewModel(player:, settings:, reminder:, coordinator:))
  tile tap   → viewModel.toggle(sound) → player.toggle(sound)   (fade in / fade out)
                                       → settings.lastSleepMix = [file name: volume]
  mini player→ viewModel.openPlayer() → AppCoordinator.presentSleepPlayer() → sheet = .sleepPlayer
       → ScreenFactory.makeScreen(for: .sleepPlayer) → SleepPlayerView(SleepPlayerViewModel(player:, settings:, coordinator:))
            slider     → player.setVolume   (saved to lastSleepMix when the finger lifts)
            timer chip → player.startTimer(minutes:) → Task: wait → 30 s fade → stopAll()
  reminder switch → viewModel.setReminder(true)
       → reminder.requestPermission() → reminder.schedule(hour:minute:) → UNUserNotificationCenter
       → settings.bedtimeReminderOn / bedtimeMinuteOfDay

Alarm rings → RingingViewModel.start() → sleepSounds.stopAll()   (no rain over your alarm)
Lock screen Play/Pause → MPRemoteCommandCenter → Task { @MainActor } → player.resume() / pause()
```

## Files, in reading order
1. `Models/SleepSound.swift`: the sounds, their icons and groups (raw value = file name)
2. `Tools/generate_sleep_sounds.py`: how the sounds were made (see `docs/ASSETS.md`)
3. `Services/Audio/SleepSoundPlayer.swift`: the mixer. **Read the WHY at the top first.**
4. `Services/Notifications/BedtimeReminder.swift`
5. `Services/Settings/AppSettings.swift` → `bedtimeReminderOn`, `bedtimeMinuteOfDay`, `lastSleepMix`
6. `Features/Sleep/ViewModels/SleepViewModel.swift` → `Views/SleepView.swift`
7. `Features/Sleep/ViewModels/SleepPlayerViewModel.swift` → `Views/SleepPlayerView.swift`
8. `Coordinator/Routes.swift` (`SheetRoute.sleepPlayer`) → `AppCoordinator.presentSleepPlayer` → `ScreenFactory`
9. `Config/Info.plist` → `UIBackgroundModes: audio`
10. Tests: `RiseUpTests/MorningAndSleepTests.swift` (suite "Sleep sounds") + `RingingFlowTests.alarmStopsSleepSounds`

## Data
| Reads | Writes |
|---|---|
| Sound files in the app bundle (`Resources/SleepSounds/*.caf`) | `AppSettings` (UserDefaults): last mix, reminder on/off + time |
| | One pending notification request (`riseup.bedtime`) in iOS |

Nothing new in SwiftData.

## Design decisions (WHY)
- **The mixer is a service, not part of a ViewModel.** A ViewModel dies with its screen, but the music must keep
  playing after you leave the Sleep tab and lock the phone. Both screens read the same `SleepSoundPlayer`, so
  they always agree (single source of truth). Even the timer length lives there (`timerMinutes`), so the right chip
  is lit when you reopen the sheet.
- **Max 3 sounds:** more than that turns into mush, and each sound is another player decoding audio all night.
- **Mini player at the BOTTOM (found in the Simulator):** at the top, it (and the hint) pushed the tiles down
  right while you were tapping them, so the next tap hit the wrong sound.
- **Player sheet opens full height:** at half height, the volume sliders were hidden.
- **Loudness normalised (RMS 0.15)** in the generator: white noise was 3× louder than rain before.
- **`.playback` audio session + `UIBackgroundModes: audio`:** plays in Silent mode and keeps the app alive while
  locked. That's also why a simple `Task.sleep` timer works all night.
- **An alarm stops the mix** (`RingingViewModel.start`). AlarmKit's sound would play anyway, but waking up to
  rain under the alarm is confusing.
- **The reminder is a notification, not an alarm:** a gentle banner, not a ringing phone.

## Test on the iPhone (the Simulator can't prove these)
- Start a mix, lock the phone: still playing? Play/Pause on the lock screen works?
- 15-min timer with the phone locked: fades out and stops?
- Mix playing + an alarm rings: the mix stops?
- Phone call during the mix: afterwards the mini player shows "paused" (tap Play to continue).
- Bedtime reminder arrives at the set time.

## Exercises
Since #39 the mix is also controlled from a mini player on the tab bar, on every tab: `docs/screens/39-sleep-mini-player.md`.

1. **TRY:** change `sleepMixMaxSounds` to 4 (top of `SleepSoundPlayer.swift`).
2. **TRY:** add 120 to `SleepPlayerViewModel.timerChoices`.
3. Change the reminder text in `NotificationBedtimeReminder.schedule`.
