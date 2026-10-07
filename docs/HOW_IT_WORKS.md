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
 ├─ @State AppDependencies ──┬─ ModelContainer      (the database file)
 │                           ├─ AlarmRepository     (ONE, shared; holds the live `alarms` list)
 │                           └─ AlarmKitScheduler   (ONE, shared; talks to iOS)
 ├─ @State AppCoordinator    (ONE, shared; all navigation state)
 └─ RootView
     └─ each screen
         └─ @State its ViewModel   (lives as long as that screen is on the stack)
```

- **Shared, long-lived:** repository, scheduler, coordinator. Created once, injected everywhere.
- **Per-screen, short-lived:** ViewModels. Created by `ScreenFactory`, kept alive by the screen's `@State`.
- **Throwaway:** View structs and `AlarmRow` snapshots. SwiftUI creates and discards them constantly. That's normal and cheap.
- **Exception:** `AlarmLaunchRouter.shared` is a singleton, because iOS creates `StartMissionIntent` outside our view tree (see its WHY comment).

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
| 7 | `AlarmListView.task` | calls `viewModel.load()` |
| 8 | `AlarmListViewModel.load()` | `repository.refresh()`, then reconciles with iOS (Trace D) |
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

### Trace D: Reconcile (database ↔ iOS)
Runs inside `AlarmListViewModel.load()` every time the list appears.
```
for each alarm that is ON in our database but NOT in iOS's list (and not "busy"):
    repeating → schedule it again          (iOS lost it, e.g. reinstall)
    one-time  → mark it OFF                (it already rang)
```
Backups are deliberately NOT cancelled here; see the WHY in the code.

### Trace E: Alarm rings → "Start Mission" (needs the widget extension; see SPIKE_RESULTS)
```
iOS rings the AlarmKit alarm (app may be closed)
 → user taps "Start Mission"
 → iOS launches/opens RiseUp and runs StartMissionIntent.perform()
     → AlarmManager.stop(ringing id)
     → AlarmLaunchRouter.shared.requestRinging(alarmID)
 → RootView .onChange(of: launchRouter.pendingAlarmID) fires
     → coordinator.presentRinging(alarmID) → fullScreen = .ringing(id)
 → .fullScreenCover → ScreenFactory.makeScreen(for: .ringing) → RingingPlaceholderView
```

---

## Part 4 · Three real bugs we hit, and the design rule each one taught us

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
