# #39 Sleep sounds mini player (+ the typing mission fix)

**Phase 7+** · on `development` · no database change

## What it does
While sleep sounds are on, a **glass mini player sits on the tab bar on every tab** (like Apple Music's):
```
[🌧]  Rain + Ocean                ⏸   ✕
      Stops in 23:41
```
- **Tap the bar** → the full mixer (volumes, sleep timer), the same Now Playing sheet as before.
- **⏸ / ▶** pauses and plays. **✕** stops everything; the bar disappears by itself.
- The second line: "Stops in 23:41" (counts down live), "Paused · stops in 23:41", "Paused", or a hint.
- Three or more sounds: "Rain + 2 more". On the Sleep tab itself the bar hides (that tab has its own card).
- When the tab bar is minimised, iOS squeezes the bar ("inline"): then only icon, name and ⏸.

Found by Salman on his iPhone 16: with sounds playing, nothing outside the Sleep tab showed it, and stopping
them meant finding the Sleep tab first.

## Connection map
```
RootView TabView .sleepMiniPlayer(isVisible: SleepMiniPlayerViewModel.isVisible(activeSounds:selectedTab:))
   iOS 26.1+ → .tabViewBottomAccessory(isEnabled:)      iOS 26.0 → glass overlay just above the tab bar
   → ScreenFactory.makeSleepMiniPlayer() → SleepMiniPlayer(viewModel: SleepMiniPlayerViewModel)
        tap  → AppCoordinator.presentSleepPlayer() → sheet .sleepPlayer (Screen #20)
        ⏸/▶  → SleepSoundPlayer.pause / resume        ✕ → SleepSoundPlayer.stopAll
```

## Files, in reading order
1. `Alarm/Features/Sleep/ViewModels/SleepMiniPlayerViewModel.swift`
2. `Alarm/Features/Sleep/Views/SleepMiniPlayer.swift` (+ the `sleepMiniPlayer(isVisible:)` modifier at the bottom)
3. `Alarm/Coordinator/RootView.swift` (where it's attached), `ScreenFactory.makeSleepMiniPlayer`
4. Tests: `RiseUpTests/MorningAndSleepTests.swift` → "Sleep mini player on the tab bar (#39)"

## The typing mission fix (same session)
After the first phrase matched, the next phrase appeared but the box still held the old text, and new letters
were added to it ("I am wide awakeN"). Cause: the old text field wrote its text back once more on its way
out. Fix: a new field per phrase (`.id(viewModel.index)`), every write says which phrase it belongs to
(`type(_:forPhrase:)`, late writes ignored), and the new field gets the keyboard 50 ms later. Test:
`MissionSafetyTests` → "Typing: after a phrase, the box starts EMPTY…". HOW_IT_WORKS Bug 54.

## Test on the iPhone
1. Sleep tab → Rain → Alarms tab: the bar shows. ⏸, ▶, tap → mixer, set 15 min → "Stops in 14:59".
2. ✕ → silence, the bar is gone. Lock the phone with sounds on: the lock screen controls still work too.
3. Typing mission with 3 phrases, typed on the real keyboard: each new phrase starts with an empty box and the
   keyboard stays up.

## Exercises
1. **TRY:** in `SleepMiniPlayerViewModel.title`, change `> 2` to `> 1` and see "Rain + 1 more".
2. Why is the bar hidden on the Sleep tab? Find the rule and its test.
