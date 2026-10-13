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
   → scheduler.missionCompleted(alarm)     cancel today's backups + snooze; re-arm next occurrence
   → one-time: isEnabled = false · quick: deleted
   → WakeRecord: dismissedAt, missionSeconds, missionsCompleted
   → phase = .success → SuccessView (confetti) → "Start my day" → dismissFullScreen()

If the user pressed STOP instead: backups ring at 06:31, 06:32, 06:33, 06:35, 06:38.
Meanwhile the alarm is LOCKED (hasPendingMission): no switching off, deleting or editing,
and the Alarm List shows "Finish your mission".
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
  That logic now lives in `AlarmKitScheduler.hasPendingMission`, next to the backup offsets it depends on.

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
