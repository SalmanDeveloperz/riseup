# How RiseUp Works: System Design, Step by Step

This is the "connect the dots" guide. `ARCHITECTURE.md` shows the boxes; this file shows how
**things move between the boxes**. Read it with Xcode open and jump to each file as it's mentioned
(⇧⌘O "Open Quickly", then type the file name).

---

## Part 1 · The 5 ways pieces of the app talk to each other

Every connection in RiseUp is one of these five. Once you recognise them, the codebase stops
looking like magic.

| # | Mechanism | Direction | Example in our code | Look for |
|---|---|---|---|---|
| 1 | **Environment injection** | top → any view below | `RiseUpApp` puts `AppDependencies` + `AppCoordinator` in the environment; `RootView` reads them | `.environment(x)` / `@Environment(X.self)` |
| 2 | **Init injection** | creator → created | `ScreenFactory` creates `AlarmListViewModel(repository:scheduler:coordinator:)` | parameters of `init` |
| 3 | **Closures (callbacks)** | child → parent | `AlarmCardView(onToggle:onTap:)` tells the list "user flipped the switch" | `let onX: () -> Void` |
| 4 | **Observation** | data → UI (automatic) | a ViewModel's property changes → the View that read it redraws | `@Observable`, `@State` |
| 5 | **Bindings** | two-way | `NavigationStack(path: $coordinator.alarmsPath)` | `$something`, `Binding(get:set:)` |

Rule of thumb:
- **Down** the tree: injection (1, 2).
- **Up** the tree: closures (3), or calling a ViewModel method.
- **Back down after a change**: observation (4). We NEVER manually "refresh the screen".

---

## Part 2 · Who owns what (object lifetimes)

```
RiseUpApp  (lives as long as the app)
 ├─ @State AppDependencies ──┬─ ModelContainer        (the database file)
 │                           ├─ AlarmRepository       (ONE, shared; holds the live `alarms` list)
 │                           ├─ WakeRecordRepository  (ONE, shared; wake-up history)
 │                           ├─ AlarmKitScheduler     (ONE, shared; talks to iOS)
 │                           ├─ AlarmSyncService      (ONE, shared; database ↔ iOS agreement)
 │                           ├─ AudioService          (ONE, shared; previews + in-app alarm sound)
 │                           ├─ SpeechTimeAnnouncer   (ONE, shared; "Time Pressure" voice)
 │                           ├─ MissionServices       (ONE bundle: shake, steps, squat sensors + photo matcher)
 │                           └─ AppSettings           (ONE, shared; small preferences in UserDefaults)
 ├─ @State AppCoordinator    (ONE, shared; all navigation state)
 └─ RootView
     └─ each screen
         └─ @State its ViewModel   (lives as long as that screen is on the stack)
```

- **Shared, long-lived:** repository, scheduler, coordinator. Created once, injected everywhere.
- **Per-screen, short-lived:** ViewModels. Created by `ScreenFactory`, kept alive by the screen's `@State`.
- **Throwaway:** View structs and `AlarmRow` snapshots. SwiftUI creates and discards them constantly. That's normal and cheap.
- **Exception:** `AlarmLaunchRouter.shared` is a singleton, because iOS creates `StartMissionIntent` outside our view tree (see its WHY comment).
- **A second program:** the `RiseUpWidgets` extension is started by iOS, not by `RiseUpApp`. It shares no objects with
  the app, only source files (the `Shared/` folder) and the data iOS hands it (`AlarmAttributes`).

---

## Part 3 · Traces (follow one action through every file)

### Trace A: App launch → Alarm List on screen
| Step | File · function | What happens |
|---|---|---|
| 1 | `RiseUpApp` | `@State dependencies = AppDependencies.live()` |
| 2 | `AppDependencies.live()` | `ModelContainerFactory.make()` opens the database; creates `AlarmRepository` + `AlarmKitScheduler` |
| 3 | `AlarmRepository.init` | `refresh()` loads all alarms into `alarms` |
| 4 | `RiseUpApp.body` | shows `RootView`, injecting dependencies + coordinator (mechanism 1) |
| 5 | `RootView.body` | builds `ScreenFactory`, `TabView` bound to `coordinator.selectedTab` (= `.alarms`) |
| 6 | `ScreenFactory.makeRoot(for: .alarms)` | creates `AlarmListViewModel(...)` (mechanism 2) and `AlarmListView` |
| 7 | `RootView.onChange(of: scenePhase, initial: true)` | app is `.active` → `AlarmSyncService.sync()` (Trace D); if an alarm is ringing → Ringing screen (Trace H) |
| 8 | `AlarmListView.task` → `AlarmListViewModel.load()` | `repository.refresh()`, then `sync()` again (cheap; skipped if one is already running) |
| 9 | `AlarmListView.body` | reads `viewModel.rows` → `repository.alarms.map(makeRow)` → draws one `AlarmCardView` per row |

### Trace B: User flips a switch ON
| Step | File · function | What happens |
|---|---|---|
| 1 | `NeonToggleStyle` | tap → `configuration.isOn.toggle()` → the Binding's `set` runs |
| 2 | `AlarmCardView.isOnBinding` | `set` calls `onToggle(true)` (mechanism 3, closure going UP) |
| 3 | `AlarmListView` | the closure starts `Task { await viewModel.setEnabled(true, alarmID: row.id) }` |
| 4 | `AlarmListViewModel.setEnabled` | finds the live `WakeAlarm` by ID; sets `alarm.isEnabled = true` |
| 5 | *(observation)* | `rows` depended on `isEnabled` → list redraws → new `AlarmRow` → card glows (mechanism 4) |
| 6 | `requireAlarmPermission()` | first time only: the system "Allow alarms?" popup |
| 7 | `AlarmKitScheduler.schedule` | marks the alarm "busy", cancels old versions, schedules main (+ backups if missions) with `AlarmManager` |
| 8 | `AlarmRepository.save()` | writes to disk, then `refresh()` |
| 9 | on error | roll back `isEnabled = false`, set `errorMessage` → the alert appears (observation again) |

### Trace C: User taps "+"
| Step | File · function | What happens |
|---|---|---|
| 1 | `FloatingAddButton` | calls its `action` closure |
| 2 | `AlarmListView` | the closure calls `viewModel.addAlarmTapped()` |
| 3 | `AlarmListViewModel.addAlarmTapped` | `coordinator.showAlarmEditor(alarmID: nil)` |
| 4 | `AppCoordinator.showAlarmEditor` | `alarmsPath.append(.editor(alarmID: nil))` |
| 5 | `RootView` | `NavigationStack(path: $coordinator.alarmsPath)` sees a new element (mechanism 5) |
| 6 | `.navigationDestination(for: AlarmsRoute.self)` | asks `ScreenFactory.makeScreen(for: .editor(nil))` |
| 7 | `ScreenFactory` | returns the editor screen (a placeholder until the next chunk) |
| 8 | Back button | SwiftUI removes the last element from `alarmsPath` for us; the binding works both ways |

### Trace D: Sync (database ↔ iOS), `AlarmSyncService.sync()`
Runs on launch, every time the app comes to the front, and when the Alarm List appears.
(It used to live in `AlarmListViewModel`; it moved to a service because the *launch* needs it too.)
```
ask iOS for every system alarm (AlarmScheduling.systemAlarms)
for each alarm that is ON in our database (and not "busy" = isScheduling):
    main alarm missing in iOS?
        quick alarm → delete it          (it rang; quick alarms are throwaway)
        one-time    → switch it OFF      (it rang)
        repeating   → schedule it again  (iOS lost it, e.g. reinstall)
    repeating mission alarm without backups → ensureBackupChain  (yesterday's mission never finished)
cancel every system alarm that belongs to nobody (cancelSystemAlarms(notIn:))
    (backups of existing alarms are KEPT: a mission may still be pending)
```

### Trace E: Alarm rings → "Start Mission" (needs the widget extension; see SPIKE_RESULTS)
```
iOS rings the AlarmKit alarm (app may be closed)
 → user taps "Start Mission"
 → iOS launches/opens RiseUp and runs StartMissionIntent.perform()
     → AlarmManager.stop(ringing id)
     → AlarmLaunchRouter.shared.requestRinging(alarmID)
 → RootView .onChange(of: launchRouter.pendingAlarmID) fires
     → coordinator.presentRinging(alarmID) → fullScreen = .ringing(id)
 → .fullScreenCover → ScreenFactory.makeScreen(for: .ringing) → RingingView (Trace H)
```

### Trace F: Saving an alarm in the Editor
| Step | File · function | What happens |
|---|---|---|
| 1 | `AlarmEditorView` toolbar | "Save" → hides the keyboard → `Task { await viewModel.save() }` |
| 2 | `AlarmEditorViewModel.save` | `isSaving = true` (button disabled), then `scheduler.requirePermission()`: popup the first time |
| 3 | same | Edit mode: `repository.fetch(id:)` → copy the draft into it. New: `makeAlarm(from: draft)` |
| 4 | `AlarmRepository.save()` / `insert()` | writes to disk, then `refresh()` → `repository.alarms` changes |
| 5 | *(observation)* | the Alarm List (still alive under the editor) already redraws with the new card |
| 6 | `AlarmKitScheduler.schedule` | cancels any old version, schedules main (+ backups if missions) |
| 7 | `AppCoordinator.popAlarms()` | `alarmsPath.removeLast()` → the NavigationStack slides back to the list |
| 8 | `AlarmListView.task` | runs `load()` → reconcile finds the alarm in iOS, so it stays ON |
| ✗ | permission denied / iOS error | the alarm is saved but OFF; the alert's OK pops back (`closesAfterError`) |

### Trace G: A sheet that returns a result (Sound Picker; the Mission Picker works the same way)
| Step | File · function | What happens |
|---|---|---|
| 1 | `AlarmEditorView` Sound card | tap → `viewModel.chooseSound()` |
| 2 | `AlarmEditorViewModel.chooseSound` | `coordinator.presentSoundPicker(selected: draft.sound) { [weak self] in self?.draft.sound = $0 }` |
| 3 | `AppCoordinator.presentSoundPicker` | stores the closure in `onSoundPicked` (`@ObservationIgnored`), sets `sheet = .soundPicker(...)` |
| 4 | `RootView .sheet(item: $coordinator.sheet)` | → `ScreenFactory.makeScreen(for: SheetRoute)` → `SoundPickerView` + ViewModel |
| 5 | `SoundPickerViewModel.select` | highlights the row, `audio.preview(sound)` |
| 6 | "Done" → `SoundPickerViewModel.done()` | `coordinator.completeSoundPicker(with: selected)` |
| 7 | `AppCoordinator.completeSoundPicker` | runs the stored closure (step 2) → the editor's draft changes → closes the sheet, forgets the closure |
| ✗ | Cancel / swipe down | `dismissSheet()` → closure forgotten, draft unchanged |

Why `[weak self]`: the coordinator lives for the whole app. If it held the editor's ViewModel strongly
through the closure, a closed editor could stay in memory. `weak` = "call me if I still exist".

### Trace H: A mission alarm from ring to "You're up!"
```
06:30  iOS rings the main alarm (AlarmKit; phone may be locked, app closed)
       └─ unlocked phone: the Live Activity UI comes from OUR widget extension (RiseUpWidgets)
 user taps "Start Mission"  → StartMissionIntent → AlarmLaunchRouter → RootView → presentRinging
   (or opens RiseUp any other way → RootView sync → ringingAlarmID() → presentRinging)
 RingingViewModel.start()
   → scheduler.stopRinging(alarm)          iOS's sound off
   → audio.startAlarm(sound, rampUp:)      OUR sound on (quiet → loud)
   → records.openRecord(...)               WakeRecord row (reused after a snooze)
 "Start Mission" → phase = .mission(0) → sound muted → 15 s idle watchdog starts
   each tap/key/shake → userInteracted()   (stay quiet)
   idle 15 s          → sound back + red banner
   mission solved     → missionFinished()  → next mission, or finish()
 finish()
   → scheduler.wakeUpCompleted(alarm)      cancel today's backups + snooze; re-arm next occurrence
   → one-time: isEnabled = false · quick: deleted
   → WakeRecord: dismissedAt, missionSeconds, missionsCompleted
   → phase = .success → SuccessView (confetti) → "Start my day" → dismissFullScreen()

If the user pressed STOP (or a side/volume button) instead: backups ring at 06:30:30, 06:31, 06:31:30,
06:32, 06:33, 06:35, 06:38, 06:42 (since #34; see Trace P).
Meanwhile the alarm is LOCKED (hasPendingWakeUp): no switching off, deleting or editing,
and the Alarm List shows "Finish waking up".
```

### Trace I: A sensor mission that can't run (the safety net)
```
RingingView → MissionView(mission: .steps, services:)            replacement = nil
  → StepsMissionViewModel.start()
       counter.isAvailable == false (Motion & Fitness denied)
         Simulator? → canSimulate = true ("Simulate 5 steps")
         iPhone?    → onUnavailable()  ─┐
  MissionView.useFallback  ◄────────────┘   replacement = .unavailable
  → body redraws: banner + MathMissionView(3 normal problems)
  → same onComplete → RingingViewModel.missionFinished()   (the alarm can still be finished)
Photo/Barcode after 3 failed tries → "Can't match?" → onGiveUp → replacement = .gaveUp → 5 HARD problems
```

### Trace J: Registering and checking a photo spot
```
Mission Settings "Take photo" → MissionPickerViewModel.takePhoto()
  → CameraAccess.requestIfNeeded()            (camera popup, once)
  → isShowingCamera = true → .photoCapture → UIImagePickerController (library in the Simulator)
  → registerPhoto(image)
       CameraAccess.jpegData(image)            640 px, upright
       photoMatcher.fingerprint(jpeg)          Vision, @concurrent = off the main thread
       PhotoMissionPayload(fingerprint, thumbnail).encoded() → draft.dataPayload
  → Add mission → editor Save → MissionConfig.dataPayload (external storage)
Morning: PhotoMissionViewModel.check(newPhoto)
  → fingerprint(new) → distance(registered, new) ≤ matchThreshold ? ✓ : "doesn't look like the same spot"
```

### Trace K: First launch (onboarding)
```
RiseUpApp → AppDependencies.live() → AppSettings(): hasCompletedOnboarding = false (never saved)
RootView .onChange(of: settings.hasCompletedOnboarding, initial: true)
  → AppCoordinator.presentOnboarding() → fullScreen = .onboarding → OnboardingView
  → … "Create my alarm" → repository.insert + replaceMissions → scheduler.schedule
  → finish(): hasCompletedOnboarding = true (saved) → dismissFullScreen()
Next launches: the flag is true → no onboarding. Settings → Replay intro sets it to false again.
```

### Trace L: Picking a mood → the Morning tab and Stats update by themselves
```
SuccessView 🙂 tap → onMood(.good) → RingingViewModel.setMood(.good)
  → WakeRecordRepository.setMood(.good, forRecordID:) → record.moodRawValue = 4 → save()
  → save() calls refresh() → entries = fetched records mapped to WakeEntry values   (live list replaced)
MorningViewModel.todayEntry(now:) and StatsViewModel.points(now:) are COMPUTED from records.entries
  → @Observable notices `entries` changed → MorningView and StatsView redraw. Nobody had to "send" anything.
```

### Trace M: Rain at bedtime → lock screen → alarm in the morning
```
SleepView tile tap → SleepViewModel.toggle(.rain) → SleepSoundPlayer.toggle(.rain)
  → AVAudioSession .playback (works in Silent mode) → AVAudioPlayer loops sleep_rain.caf, fades 0 → 0.7
  → MPNowPlayingInfoCenter: "Rain" on the lock screen · settings.lastSleepMix = ["sleep_rain": 0.7]
Phone locked → UIBackgroundModes: audio keeps RiseUp running while it plays
Lock screen ⏸ → MPRemoteCommandCenter (any thread) → Task { @MainActor in player.pause() }
Sleep timer 30 min → Task.sleep(29.5 min) → fade 30 s → stopAll()
…or the alarm rings first → RingingView → RingingViewModel.start() → sleepSounds.stopAll()
```

---

## Part 4 · Real bugs we hit, and the design rule each one taught us

These happened while building the Alarm List, and they're the best system-design lessons so far.

### Bug 1: Stale copy → crash
- **What happened:** the list ViewModel kept its own `alarms` array. The AlarmKit Lab deleted alarms. The list still held them, drew them, and SwiftData crashed.
- **Rule: single source of truth.** One owner (`AlarmRepository.alarms`), refreshed inside every write. Everyone else reads it and never keeps a copy.

### Bug 2: Live database object in a View → crash
- **What happened:** even with one list, each card held a live `WakeAlarm`. Deleting it notified the card's observers, the card redrew once more, read a deleted object, and crashed.
- **Rule: Views receive value snapshots (`AlarmRow`), never `@Model` objects.** Only ViewModels touch live objects, and they look them up by ID at the moment they act.

### Bug 3: Race condition → alarm switched itself off
- **What happened:** the Lab saved an alarm as ON and *then* scheduled it (~0.1 s). The list's reconcile ran in between: "ON in database but not in iOS?" → switched it OFF. The logs proved the timing: schedule start `.833s` → reconcile `.879s` → schedule end `.932s`.
- **Rule: anything comparing two systems must know about work in progress.** `AlarmScheduling.isScheduling(_:)` tells the reconcile to skip alarms that are mid-schedule.
- **Lesson:** `async` code on the main actor still interleaves at every `await`. "Main actor" means one thing at a time, NOT one whole function at a time.

### Bug 4: Xcode Preview crash: the database disappeared
- **What happened:** a `#Preview` built `let dependencies = AppDependencies.preview()` and passed only the repository on. When the preview finished building, `dependencies` was released, and so was its `ModelContainer`. The repository's `ModelContext` doesn't keep the container alive, so the first fetch crashed inside SwiftData.
- **Rule: whoever uses a `ModelContext` must also keep its `ModelContainer` alive.** `AlarmRepository` now stores `context.container`.
- **Lesson:** "it works in the app" isn't enough. The app kept `AppDependencies` alive by luck of structure (`@State` in `RiseUpApp`); previews and tests don't.

### Bug 5: The mission lock switched on before the alarm even rang
- **What happened:** the first rule was "locked if a backup is due within 10 minutes". At 06:25 the 06:31 backup
  was "due soon", so you couldn't switch off an alarm that hadn't rung yet.
- **Rule: describe the real event, not a time window near it.** A mission is pending if one of the alarm's system
  alarms is *alerting*, or if the *main ring time* (backup date − its offset) has already passed.
  That logic now lives in `AlarmKitScheduler.hasPendingWakeUp` (renamed from `hasPendingMission` in #34) and the
  pure rule `AlarmScheduleCalculator.isWakeUpPending`.

### Bug 6: The countdown said "2m" for a whole minute
- **What happened:** the header used `TimelineView(.everyMinute)`'s `context.date`, which is the start of the
  minute, not the current second. With 61 s left it computed from up to 59 s in the past.
- **Rule:** a `TimelineView` tells you *when to redraw*. Read the real time (`Date.now`) for the maths.

### Bug 7: The example in Mission Settings flickered
- **What happened:** `sampleText` was a computed property that generated a *random* problem. Every redraw
  (every tap on −/+) produced a new one.
- **Rule: computed properties must be cheap and give the same answer for the same state.** Random or
  expensive results are *stored* and refreshed on purpose (`refreshSample()` when type or difficulty changes).

### Lesson: changing a released model = a new schema version
`fixedFireDate` (quick alarms) and the new `WakeRecord` model changed the database. Instead of editing `SchemaV1`
(frozen forever once shipped), we added `SchemaV2` plus a *lightweight* migration stage in `RiseUpMigrationPlan`.
Tested on the Simulator's existing database: all 9 old alarms survived, and the new table appeared.
Lightweight works for "add an optional field / add a model". Renames or data changes need a *custom* stage.

### Lesson: two programs, one set of types (the widget extension)
The widget extension can't see app files. Anything both sides need (the alarm metadata type and the colours)
lives in `Shared/`, a folder that belongs to both targets. If the two sides used *different* copies of
`RiseUpAlarmMetadata`, iOS couldn't match the alarm to our UI.

### Bug 8: Vision said a flower photo matched a waterfall (Simulator)
- **What happened:** Vision's feature prints fail in the Simulator. Forced onto the CPU they "worked", but a
  throwaway test showed every photo got the SAME fingerprint (distance 0.0), so everything matched.
- **Rules:** (1) *measure, don't assume*: a 30-line scratch test settled it in a minute. (2) When a framework
  can't run somewhere, swap the implementation behind the protocol (`PixelPhotoMatcher` in the Simulator).
  That's exactly what the protocol is for.

### Bug 9: The Simulator "has a camera", but it can't take photos
- **What happened:** `UIImagePickerController.isSourceTypeAvailable(.camera)` is true in newer Simulators, but the
  shutter does nothing. Our camera code path was unusable there.
- **Rule:** decide by what you actually need. `CameraAccess.usesRealCamera` = camera **and** a real device.

### Bug 10: Tips listed above the green checks in "Check my alarms"
- **What happened:** the status enum's order was ok, info, warning, problem, so "info" ranked above "ok".
- **Rule:** when an enum's order means something, write the order down (raw values + a WHY) and test it
  (`HealthCheckTests`).

### Bugs 11–15: found by a code review, not by testing
A second pair of eyes read every new file asking one question: *"how could someone end up stuck with a ringing
alarm?"* None of these showed up in normal Simulator testing:
- **Two Shake (or Squat/Steps) missions in a row:** one shared sensor. The first mission's screen disappears
  *after* the second one started, and its `stop()` switched the sensor off → the second mission could never finish.
  Fix: each mission ViewModel only stops a sensor it is still running (`isRunning`).
- **"Start Mission" while a sheet is open:** SwiftUI won't show a full-screen cover over a sheet → silence, no mission.
  Fix: `AppCoordinator.presentRinging` closes the sheet first.
- **Opening the app during a ring before finishing onboarding:** the intro won. Fix: ringing replaces onboarding.
- **A mission reporting "done" twice** (typing one more letter after the last phrase) skipped the NEXT mission.
  Fix: report done exactly once; `finish()` also guards against running twice.
- **Memory could freeze** if its screen disappeared and came back mid-round. Fix: `start()` restarts the round.

**Rule:** for the scariest failure ("can't turn the alarm off"), test the happy path AND have someone read the code
looking only for that failure. Each fix now has a test in `RiseUpTests/MissionSafetyTests.swift` or `RingingFlowTests.swift`.

### Lesson: Swift 6 and callbacks from other threads
CMPedometer calls its closure on a background thread. In our project (main actor by default) an un-annotated
closure would be *assumed* main-actor, and Swift 6 checks that at runtime: **crash**. Mark such closures
`@Sendable` and hop back with `Task { @MainActor in … }` (see `StepCounter.swift`). APIs that let you choose
`to: .main` (motion updates) are simpler: then `MainActor.assumeIsolated` is enough.

### Lesson: hardware on its own queue
`CameraSession` is `nonisolated` with a private `DispatchQueue`: every slow camera call happens there, and
`withCheckedContinuation` turns "call me back" into `await`. The screen stays responsive no matter how long
the hardware takes. The same idea applies to anything slow that Apple doesn't already make async.

### Lesson: some state must outlive every screen
A ViewModel lives exactly as long as its screen. The sleep-sound mix (and its timer) must keep going after you
leave the Sleep tab and lock the phone, so it lives in `SleepSoundPlayer`, created once in `AppDependencies`.
Both Sleep screens just read it, so they can never disagree. **Rule:** if it must keep running when the screen
is gone, it's a service.

### Bug 16: Tiles jumped under the finger (Simulator)
The "now playing" bar and the "max 3 sounds" hint appeared ABOVE the sound grid, pushing every tile down right
after a tap, so the next tap landed on a different sound. Fix: a bottom `safeAreaInset` mini player (like Apple
Music). **Rule:** never insert content above the thing the user is tapping.

### Bug 17: Today's dot was cut in half (charts)
The chart's x-axis ended at midnight at the START of today, but a day's dot is drawn in the middle of its day.
Fix: the axis ends one day later (`WakeTimeChart`). Also: Swift Charts already draws times top-down (earlier
higher). We first "reversed" it, which did nothing visible and confused us. Read the axis labels before "fixing".

### Bug 18: White noise was 3× louder than rain
Each generated sound had a different loudness, so a mix needed fiddling with sliders. Fix: the generator measures
each sound's RMS ("average loudness") and scales it to the same value (0.15). **Rule:** measure; don't trust your ears.

### Bug 19: An arrow that looked tappable but wasn't
Records' "next month" arrow was `.disabled` on the current month, but our explicit pink colour hid SwiftUI's grey
disabled look. Fix: dim it ourselves with `.opacity`. **Rule:** a custom colour means you style every state.

### Trace N: An alarm rings with a live wallpaper
```
RingingViewModel.start() → info.wallpaper = Wallpaper(rawValue: alarm.wallpaperID) ?? settings.defaultWallpaper
                         → .resolved() ("Surprise" → today's wallpaper) · ringStartedAt = now
                         → photo? WallpaperStore.image(for:) (background decode, memory cache)
RingingView.background → WallpaperView(energy: .ramp(start: ringStartedAt, duration: 40), showsScrim: true)
  → LiveWallpaperView: TimelineView(.animation) every frame →
       level = energy.level(at: now)          (0 → 1 over 40 s: brightness, size, count)
       time  = energy.clock(elapsed, boost)   (bent time: speeds up smoothly, never jumps)
       Canvas → SynthwaveRenderer.draw(context, size, time, level)
  phase .mission → black 72 % overlay (focus) · phase .success → energy .fixed(1) (celebrate)
```

### Lesson: never multiply time by something that changes
`time × speed` looks harmless, but when `speed` changes a tiny bit, a big `time` makes everything jump. The fix is
the physics one: position = area under the speed curve (an integral). `WallpaperEnergy.clock` has the formula, and
a test checks it never jumps or goes backwards.

### Lesson: look at what you draw
Rendering every wallpaper to PNG in a throwaway test (ImageRenderer) and viewing them side by side found four
problems in one minute: a mesh gap, hidden stripes, faint aurora, dotty clouds. Then the Simulator found the clock
being hard to read on a bright sun. **Rule:** for visual code, look at the output, not just the build.

### Trace O: Tap a wallpaper, hear it, choose it with its sound
```
WallpaperPickerView card tap → viewModel.openPlayer(.live(.kyotoBlossoms))
  → playlist = this tab's wallpapers · playerIndex = its position · isShowingPlayer = true
  → audio.previewLooping(.koto)            (AudioService: plays the 12 s file, numberOfLoops = -1)
.fullScreenCover(isPresented: $viewModel.isShowingPlayer) → ScenePlayerView
  ⏭ → next() → playerIndex + 1 (wraps) → .id(wallpaper) fades in the new scene → its sound replaces the old one
  ♥ → toggleSaved() → AppSettings.savedWallpapers.insert("live.kyotoBlossoms", at: 0)
  "Use wallpaper + sound" → use(withSound: true) → closePlayer() (sound stops) → 350 ms
     → coordinator.completeWallpaperPicker(with: WallpaperChoice(wallpaper:, sound: .koto))
     → AlarmEditorViewModel onPick → draft.wallpaper + draft.sound → Save → WakeAlarm.wallpaperID, soundName
```

### Bug 41: A symbol that doesn't exist (caught by a test)
Savanna Drums used `drum.fill`, which isn't an SF Symbol: the icon would just be blank, no error. The new test
`symbolsExist` asks `UIImage(systemName:)` for every sound and category icon and failed at once. Fix:
`hands.clap.fill`. **Rule:** names written as strings are never checked by the compiler, so check them in a test.

### Bug 42: The clock's shadow greyed out the sun
The dark "halo" that keeps the clock readable was a full-screen layer, so it also dimmed suns and snowy peaks.
Fix: `clockHalo()` sits behind the clock only. Its first version showed the edges of its square; a bigger frame
squeezed into an oval (`scaleEffect(y: 0.7)`) fades out before the edge.

### Trace P: A sleepy press on the volume button (Wake-up guarantee, #34)
```
07:00:00  main alarm rings (locked phone)          secondary button "Wake up" (or "Start Mission")
07:00:05  user presses volume down → iOS silences it (Apple's rule; no app can block this)
07:00:30  backup 0 rings "Still in bed? Tap Wake up"   (each press only silences the one ringing)
07:00:40  user taps "Wake up" → StartMissionIntent → RiseUp opens → Ringing screen
          RingingViewModel.start(): stopRinging · our sound (media volume) · startKeepAlive()
          every 30 s while in front: scheduler.holdBackupChain → serially { cancel chain; first backup = now + 75 s }
07:01:10  "I'm up" → finish(): stopKeepAliveAndWait() → wakeUpCompleted (chain gone; tomorrow armed)
If the user locks the phone on the Ringing screen instead: scenePhase → background → no more holds →
the next backup rings within ~75 s. The keep-alive is a dead man's switch.
```

### Trace Q: The home screen widget shows tomorrow's alarm on its wallpaper (#31)
```
RootView: app → background (or after a sync) → WidgetBridge.update
  plan(): ON alarms → every ring in 8 days → (event, wallpaper resolved per day)
  still(): new wallpaper? ImageRenderer(WallpaperStill) → App Group /Wallpapers/wp1-live.goldenHour.jpg
  WidgetSnapshot.save() → App Group UserDefaults; changed → WidgetCenter.reloadTimelines
iOS → RiseUpWidgets → NextAlarmProvider.getTimeline → entries at now + just after each ring
  → SmallView: TOMORROW · 7:00 AM · "in 13 hr, 4 min" (Text(date, style: .relative) ticks by itself)
Tap → riseup://alarm/<id> → RootView .onOpenURL → DeepLink → AppCoordinator.open → editor
```

### Bug 43: One press on the volume button ended the alarm (Salman's iPhone)
- **What happened:** screen off, alarm ringing, volume down → silence for good. Alarms without missions had no
  backups, and no way into the app (so the wallpaper never showed either).
- **Why:** AlarmKit lets Stop, the side button and the volume buttons silence ANY app's alarm. Apple's rule.
- **Fix:** the Wake-up guarantee (#34): every alarm re-rings 30 s later until you're up inside RiseUp, and every
  ring has a button into the app. **Rule:** when iOS won't let you prevent something, make it not matter.

### Bug 44: A keep-alive could re-arm the chain after "I'm up" (found while designing it)
- **The trap:** the Ringing screen re-arms the chain every 30 s. If "I'm up" cancelled the chain while a re-arm was
  half-way (waiting for iOS), the re-arm finished afterwards and the alarm rang again for someone already up.
- **Fix:** chain jobs run one at a time per alarm (`serially`), every cancel bumps a version that busy jobs check,
  and `finish()` awaits `stopKeepAliveAndWait()` first. **Rule:** after every `await`, ask "is this still wanted?"
  (same lesson as Bug 20).

### Bug 45: Widget text didn't fit (found in the Simulator)
- "TOMORROW" next to two mission icons wrapped onto two lines; the large widget's three two-line rows pushed the
  header off the top and the nap buttons off the bottom; the time sat on the bright sun.
- **Fix:** `lineLimit(1)` + `minimumScaleFactor`, one-line rows in the large widget (`AnyLayout`), darker
  scrim and a double shadow on the time. **Rule:** look at every widget size, with real data.

### Bug 46: A widget link opened the editor under an old sheet
- A Quick Alarm sheet left open stayed on top of the editor that a widget tap opened.
- **Fix:** `AppCoordinator.open(_:)` closes any sheet first (test `coordinatorOpensLinks`).

### Lesson: a design system pays off on the day you add themes (#35)
Light mode + 5 palettes touched ONE file of colour logic (`Theme.swift`) because no screen ever typed a raw colour.
Two things still needed care:
- **Colour names that become lies:** `neonPink` would be blue in Ocean, so the tokens became roles (`accent`…).
- **White text on gradients was spelled `textPrimary`:** that's white in dark mode only. In light mode the icon on the
  "Check my alarms" badge turned dark ink (found in the Simulator). Fix: `Theme.Colors.onAccent` for anything drawn
  ON an accent; a small script found the 6 places.
**Rule:** name colours by what they're FOR, not what they look like.

### Lesson: an icon must say what the app is, AND be ownable (the logo journey)
- **v1, a sunrise with an up-arrow:** beautiful, but it didn't say "alarm" (Salman noticed). It's also almost
  Apple's own "sunrise" SF Symbol, which anyone can use.
- **v2, a ringing twin-bell alarm clock with a sunrise face:** said "alarm", but looking at the App Store showed
  the problem: Alarmy's icon IS a pink-orange twin-bell clock, and the whole category is bells, digits and cartoon
  clock faces. v2 blended in, and its many details looked "generated".
- **The process that worked:** a "logo lab" script drew ~20 minimal concepts and put each on a fake home screen
  at real sizes (120, 60, 40, 29 px) on light and dark wallpapers. Most failed in a way you only see that way:
  sound waves read as Wi-Fi, a sun with a slot looked like a helmet, "arms raising the sun" looked like a download
  arrow, a dial with one hand looked like a power button.
- **v3, the Crowing Rooster:** a character (like Twitter's bird or Duolingo's owl, the strongest kind of brand
  asset) that means "morning" and "alarm" at once, and that no alarm app owns. **Rules:** judge an icon at 29 px next
  to other icons, not at 1024 px alone; check what the market leader looks like; one idea, few shapes.

### Trace R: "Once + Wed" at 12:00, saved on a Monday morning (#36)
```
AlarmEditorView: tap Wed, tap Once → RepeatDaysPicker → draft.alsoOnce = true
  sentence: onceAndDaysDetail(now:) → "Rings once today at 12:00 PM, then every Wed."
Save → AlarmEditorViewModel.save()
  alarm.extraOnceDate = resolvedExtraOnceDate(stored: nil, now: Mon 09:00) → onceRingDate → Mon 12:00
  → AlarmRepository.save → AlarmKitScheduler.schedule(alarm)
       scheduleMainAlarm   .relative(12:00, weekly [Wed])   ID = alarm.id
       separateOnceRing    Mon 12:00 is not a Wednesday → scheduleOnceRing .fixed(Mon 12:00)  ID = onceRingID
       backup chain after nextFireDate = min(Wed 12:00, Mon 12:00) = Mon 12:00
Mon 12:00 rings → "I'm up" → RingingViewModel.finish(): extraOnceDate = nil, alarm stays ON
  → wakeUpCompleted → chain re-armed after the next ring: Wed 12:00
(Only pressed Stop? Next launch → AlarmSyncService rule 5b: the date passed → extraOnceDate = nil)
```

### Bug 47: Saving the editor after the extra ring rang would add ANOTHER one (found while designing #36)
- **The trap:** open a Once + Wed alarm at 11:55, the extra ring rings at 12:00, then tap Save at 12:01 without
  changing anything. "Next 12:00" is now TOMORROW, so a naive save quietly creates a brand-new extra ring.
- **Fix:** `resolvedExtraOnceDate` keeps the STORED moment when the request didn't change (Once was already on, same
  time). A passed moment means "done" → `nil`. Only a new time or newly ticked Once calculates a new moment.
- **Rule:** saving without changes must change nothing. Test `editorRoundTrip` saves after the ring on purpose.

### Bug 48: Updating from a pre-widget build showed "No alarms yet" (found 2026-10-18, Simulator)
- **What happened:** a Simulator with the build from just before widgets, then today's build installed on top (a
  normal update): the alarm list was empty. The old database file was still there, untouched.
- **Why:** `ModelConfiguration("RiseUp", …)` lets SwiftData choose the folder, and SwiftData chooses the App Group
  folder as soon as the app HAS an App Group. Adding the group for the widgets silently moved where the database
  is looked for. An empty one was created, and the sync then cancelled the iOS alarms that had no row any more.
- **Fix:** `StoreRelocation` moves `RiseUp.store` + `-shm` + `-wal` + `.RiseUp_SUPPORT` into the group folder before
  the container opens. Main file last, so a crash halfway is simply finished next launch; two databases → nothing
  is overwritten. 8 tests, including a real V3 database with an alarm that must survive the move AND the V4 upgrade.
- **How it was proven:** a throwaway Simulator: old build → today's build (bug: new empty store in the group folder)
  → fixed build (the old file moved and upgraded to V4).
- **Rule:** after adding an entitlement or capability, test an UPDATE, not only a fresh install.

### Trace T: A widget's "+ Add mission" → saved to that alarm (#38)
```
NextAlarmWidget MissionLine → Link riseup://alarm/<id>/mission   (its own Link: links can't nest)
RootView .onOpenURL → DeepLink(url:) = .addMission(id) → AppCoordinator.open
   selectedTab = .alarms · alarmsPath = [] · missionRequestAlarmID = id
AlarmListView .task(id: missionRequestAlarmID) → AlarmListViewModel.handleMissionRequest()
   takeMissionRequest() (once) → addMission(toAlarm:) → lock? → presentMissionPicker(editing: nil)
Mission Picker → "Add mission" → completeMissionPicker → callback → save(mission, toAlarm:)
   replaceMissions(before + [mission]) → repository.save → scheduler.schedule (if on)
   iOS refuses? → replaceMissions(before) → message.   Back home → WidgetBridge → "⚡ Memory"
```

### Bugs 51–53: found by looking at #38 in the Simulator
- **No swipe hint:** inside the card's padding exactly 4 tiles fitted, so nothing said "there are 8". Fix: the
  strip runs to the card's edges (`contentMargins` + negative padding); the 5th tile peeks.
- **Gappy chips:** `Label` put a wide gap between icon and "Math". Fix: `HStack(spacing: 3)`.
- **"Tomorrow · Al…" on the widget:** mission icons at the row's end squeezed the text. Fix: icons next to the time.
**Rule:** a screen isn't done until you've looked at it with real data, at real size.

### Lesson: the best feature is the one people find (#38)
The missions were all there and tested; the problem was the PATH to them: below the fold, then a sheet, then
settings. The fix wasn't new code in the missions, it was fewer steps: the card moved up, the common choice became
one tap, and the places people already look (the alarm card, the widget) offer it. **Rule:** count the taps to a
feature's value, and put the entry where the eyes already are.

### Trace S: "Add your own sound" → a video from Photos → it rings (#37)
```
SoundPickerView Menu "Sound of a Video" → viewModel.chooseFromPhotos() → .photosPicker(.videos, .current)
  user picks → .onChange(pickedVideo) → viewModel.addVideo(item)
    item.loadTransferable(PickedMovie.self)  → tmp/riseup-video-….mov (an APFS clone: instant)
    → addSound → CustomSoundLibrary.add → SoundClipMaker.makeClip   (@concurrent: background thread)
         readSamples: AVAssetReader, first ≤ 60 s only → skip silence → keep ≤ 30 s
         shape: trim tail, vDSP normalise, repeat if short, fades → write: CAF IMA4
       → rename .importing-… → riseup_custom_<UUID>.caf → JSON name list
    → select(.custom(sound)) → AudioService.preview → you hear it (~0.1 s after picking)
Done → draft.sound → Save → soundName = "riseup_custom_<UUID>.caf"
  → AlarmKitScheduler.sound(named:) → AlarmSoundRule: file exists → .named(…) (missing → .default)
```

### Bug 49: A test crashed the whole test run (found while writing #37's tests)
- `AlarmRepository(context: try ModelContainerFactory.make(inMemory: true).mainContext)`: nobody kept the
  container, so Swift freed it, and its context crashed on first use. **Rule:** whoever needs a context keeps its
  container alive too (`let container` in the test).

### Bug 50: An old, innocent test started failing (the Memory mission timer)
- The new tests made minutes of audio ON THE MAIN THREAD. The Memory test waits for a real 2-second timer that
  also needs the main thread, so it ran late and failed. **Fix:** test audio is made `@concurrent` (background).
  **Rule:** a test that hogs the main thread can break OTHER tests; slow work goes to the background, in tests too.

### Lesson: measure before you optimise (#37)
"Very very fast" was the requirement. The first version took 2.4 s for a 4-minute song in the full test run. A
timing probe split it up: reading 0.25 s the first time (iOS loads its decoder once), 0.04 s after; shaping 0.005 s;
writing 0.015 s. The rest was 150 other tests running at the same time. Still, copying chunks instead of single
samples and using vDSP made it ~2× faster in Debug builds. **Rule:** time each step; fix the slow one, not a guess.

### Lesson: negative testing means listing the cases BEFORE writing code (#36)
The lead's "ring once AND on Wednesday" sounded like one checkbox. Writing the cases down first found the hard ones:
saved ON a Wednesday (one ring, not two), Tuesday evening (tomorrow IS Wednesday), exactly 12:00:00, the extra ring
already rang (Bug 47), pressed Stop and never opened the app, unticking every day, widgets planning 8 days ahead.
Each became a test named after the sentence it proves (`OnceAndDaysTests`). **Rule:** if you can't say what happens
in a case, the code can't either.

### Bug 26: Day letters sat half a day left of their dots (Salman spotted it)
A dot or bar drawn with `unit: .day` sits in the MIDDLE of its day (noon), but `.stride(by: .day)` labels sit at
MIDNIGHT (the start). Fix: `ChartDays` (in `WakeTimeChart.swift`) puts labels at noon, and every chart uses it, so
they all line up the same way. **Rule:** when two things should line up, make them use the same code.

### Bug 27: "Did it crash?" The camera froze the app (Salman's iPhone test)
Apple's `UIImagePickerController` starts the camera hardware ON THE MAIN THREAD; the first time that can take
1–3 s, and the screen can't even draw a spinner meanwhile. Fix: our own `CameraScreen` appears instantly ("Starting
camera…") while `CameraSession` starts the camera on its own background queue, and it is pre-warmed while you read
the mission screen. Photos come back already shrunk (ImageIO). **Rule:** slow system work never runs on the main
thread, and the user always sees that something is happening.

### Bug 28: The App Store build didn't compile
Every test used Debug builds. In Release, `#if DEBUG` emptied the Alarm List's toolbar builder, and an empty
toolbar builder is a compile error. Fix: the `#if` now wraps the whole toolbar item. **Rule:** before a milestone,
build the Release configuration too (`xcodebuild -configuration Release …`).

### Bugs 29–36: found by the pre-launch review of the alarm core
- **Ghost alarm:** switching ON then quickly OFF: the slow "ON" finished last and left an alarm in iOS while the
  card said OFF. Fix: one change at a time per alarm (later taps wait their turn), AND the scheduler re-checks
  "still on? still exists?" after every `await`. Test: `LaunchReadinessTests.noGhostAlarm`.
- **Half-scheduled alarm:** if a backup failed, the main alarm stayed scheduled. Fix: all-or-nothing.
- **Leftover backups** of a switched-off alarm survived the sync. Fix: kept only while its mission is pending.
- **Time zones:** backups are fixed moments, the main alarm is a clock time. After a flight the backups rang
  BEFORE the alarm. Fix: the sync re-arms backups whose time is off, and runs when the time zone or clock changes.
- **Backups over a mission:** a long mission was interrupted by iOS's +1/+2/+3 min backup alerts. Fix: while
  you're busy in the mission, ringing backups are stopped (not cancelled: they still protect you if you leave).
- **Database crash loop:** `fatalError` if the database couldn't open. Fix: retry → set the damaged file aside →
  fresh start → in-memory as a last resort, with a message to the user.
- **1 in 256 alarms** looked like a debug Lab alarm to the cleanup. Fix: the Lab exception only exists in Debug.
- **Phone call during a mission** silenced the alarm for good. Fix: it resumes when the call ends.

### Bugs 37–40: found by the smoothness review
- The editor asked the database AND iOS on every redraw (every tick of the time wheel). Fix: checked once.
- Two quick taps on Snooze = two snoozes. Fix: `isSnoozing` guard.
- Neon switches only reacted on the small capsule. Fix: the whole row, at least 44 pt tall.
- Card shadows traced every letter inside the card (slow scrolling). Fix: the shadow is on the background shape.
Plus: Reduce Motion respected, VoiceOver reads the Math keypad, bigger tap targets, day chips grow with text size.

### Bugs 20–25: found by a code review of Phases 5–6
- **The reminder switched itself back ON.** Tap ON (the permission popup waits) → tap OFF → the first call woke up
  and scheduled the reminder anyway. Fix: number each tap; after an `await`, only the newest one may act
  (`SleepViewModel.setReminder`, test `reminderRace`). **Rule:** after every `await`, ask "is this still wanted?"
- **A volume change lost to a running fade.** `player.volume = x` doesn't stop a fade in progress, so cancelling
  the timer during its last 30 s still faded to silence. Fix: a 0.1 s fade replaces the old one.
- **A timer that ended while the app slept** could stop a mix resumed from the lock screen. Fix: `resume()` drops it.
- **Average of 23:50 and 00:10 was noon.** Times wrap around midnight. Fix: average them on a clock face
  (`WakeStats.averageWakeMinute`, test `averageAcrossMidnight`).
- **A second hint vanished early** (it used the first hint's 4-second timer). Fix: `.task(id: message)`.
- **Records showed a day from another month** after ‹ ›. Fix: changing month clears the selection.

---

## Part 5 · Where to put new code (decision table)

| You need to… | Put it in… |
|---|---|
| Show something | a View (`Features/<X>/Views`), driven by ViewModel state |
| Decide something / react to a tap | the screen's ViewModel |
| Read or write the database | a Repository |
| Talk to iOS (AlarmKit, sensors, camera, StoreKit) | a Service behind a protocol |
| Go to another screen | a `Routes.swift` case + `ScreenFactory` case + `AppCoordinator` method |
| Reusable look (button, card) | `DesignSystem/Components` |
| Pure maths / formatting | a `nonisolated enum` with `static func` (easy to unit test) |
| Show a sheet that returns a value | a `SheetRoute` case + `present…(onPick:)` / `complete…(with:)` in `AppCoordinator` (Trace G) |
| Something the app AND the widget need | `Shared/` (keep it tiny: types and colours only) |
| Lock screen / Dynamic Island / widgets | `RiseUpWidgets/` |
| A new mission | `MissionType` case → rules in `MissionDraft.swift` → ViewModel + View in `Features/Missions` → `MissionView` switch; sensors via `MissionServices` |
| A small app setting | `AppSettings` (UserDefaults) + a row in `SettingsView` |
| Logic you want to be sure about | a test in `RiseUpTests/` (⌘U) |
| Something that must keep running after its screen closes (music, a timer) | a long-lived service in `AppDependencies` (like `SleepSoundPlayer`) |
| A daily reminder / banner | a service using `UNUserNotificationCenter` (like `BedtimeReminder`) |
| Statistics from the history | a pure function in `WakeStats` + a test |
| Slow hardware work (camera, files) | off the main thread: a `nonisolated` helper with its own queue, or `@concurrent` |
| A new live wallpaper | a `LiveWallpaper` case + a `…Renderer.draw` function + a line in `LiveWallpaperView.draw` |
| A flag every screen can read (like Developer mode) | an `@Entry` environment value set in RootView (`DeveloperTools.swift`) |
| A new alarm sound | a function in `Tools/generate_sounds.py` → run it → a case in `AlarmSound` → a row in `docs/ASSETS.md` |
