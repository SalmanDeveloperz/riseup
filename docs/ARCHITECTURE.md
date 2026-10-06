# RiseUp Architecture

## 1. Layers

```
┌───────────────────────────────────────────────────────────────┐
│ View (SwiftUI struct)                                         │
│   draws UI from ViewModel state; sends taps to the ViewModel  │
└──────────────▲───────────────────────────┬────────────────────┘
               │ observes (@Observable)    │ calls methods
┌──────────────┴───────────────────────────▼────────────────────┐
│ ViewModel (@Observable final class)                           │
│   screen state + logic; asks Coordinator to navigate          │
└──────┬──────────────────────┬─────────────────────────┬───────┘
       │                      │                         │
┌──────▼───────┐  ┌───────────▼──────────┐  ┌───────────▼───────┐
│ Repository   │  │ Service (protocol)   │  │ AppCoordinator    │
│ SwiftData    │  │ AlarmKit, sensors…   │  │ navigation state  │
└──────┬───────┘  └──────────────────────┘  └───────────────────┘
┌──────▼───────────────────────┐
│ Model (@Model in SchemaV1)   │
└──────────────────────────────┘
```

| Layer | Folder | Rule |
|---|---|---|
| App | `Alarm/App` | Creates `AppDependencies` + `AppCoordinator`, injects them via `.environment` |
| Coordinator | `Alarm/Coordinator` | All navigation. `ScreenFactory` builds every screen + ViewModel |
| Design System | `Alarm/DesignSystem` | Colours, fonts, reusable components. No business logic |
| Features | `Alarm/Features/<Feature>/{Views,ViewModels}` | One folder per feature |
| Repositories | `Alarm/Repositories` | Only place that touches `ModelContext` |
| Services | `Alarm/Services` | System APIs behind protocols |
| Models | `Alarm/Models` | SwiftData schema + plain value types |

## 2. Startup sequence

```
RiseUpApp
 ├─ AppDependencies.live()
 │    ├─ ModelContainerFactory.make()      → SwiftData database (SchemaV1 + migration plan)
 │    ├─ AlarmRepository(mainContext)
 │    └─ AlarmKitScheduler()
 ├─ AppCoordinator()
 └─ RootView  (.environment(dependencies), .environment(coordinator))
      ├─ TabView: Alarms | Morning | Sleep | Settings   ← coordinator.selectedTab
      │    each tab = NavigationStack; Settings is bound to coordinator.settingsPath
      ├─ .fullScreenCover(item: coordinator.fullScreen)
      └─ .onChange(AlarmLaunchRouter.pendingAlarmID) → coordinator.presentRinging
```

## 3. How a screen is created (example: AlarmKit Lab)

```
SettingsHomePlaceholderView  "AlarmKit Lab" tapped
  → closure from ScreenFactory → coordinator.show(.alarmKitLab)
  → coordinator.settingsPath.append(.alarmKitLab)
  → NavigationStack sees new path → .navigationDestination(for: SettingsRoute.self)
  → ScreenFactory.makeScreen(for: .alarmKitLab)
  → AlarmLabView(viewModel: AlarmLabViewModel(repository:, scheduler:))
```

## 4. Alarm lifecycle (AlarmKit + backup chain)

```
User saves alarm 06:30 Mon–Fri with Math mission
  → ViewModel: repository.insert(alarm); scheduler.schedule(alarm)
  → AlarmKitScheduler:
       main alarm   id = alarm.id        .relative 06:30 weekly(Mon–Fri)   button "Start Mission"
       backup 0..4  id = backupID(alarm.id, i)  .fixed next-occurrence + 1,2,3,5,8 min

06:30 alarm rings (system UI; works when locked, silent or app closed)
  ├─ "Start Mission" → StartMissionIntent.perform()
  │     → AlarmManager.stop(ringing id)
  │     → AlarmLaunchRouter.shared.requestRinging(alarm.id)
  │     → RootView → coordinator.presentRinging → Ringing screen
  │     → mission solved → scheduler.missionCompleted(alarm)
  │          → cancel today's backups → arm backups for next occurrence
  └─ "Stop" (skips mission) → backups ring at 06:31, 06:32, … until the mission is done
```

**iOS limits behind this design** (see `docs/SPIKE_RESULTS.md`):
- The system Stop button/swipe can't be hidden, and swipe-dismiss does NOT call `stopIntent`.
- On an unlocked phone the alarm is shown as a Live Activity rendered by OUR widget extension. No extension means no UI.

## 5. Data map

| Stored in SwiftData | Written by | Read by |
|---|---|---|
| `WakeAlarm` (time, repeat days, label, enabled, sound, snooze, wake-up check) | Alarm Editor, List toggle/delete, Quick Alarm, Lab | List, Editor, Ringing, Widgets |
| `MissionConfig` (type, difficulty, repetitions, order, payloads) | Mission Settings, Photo/Barcode registration | Ringing → missions |
| `WakeRecord` (Phase 2) | Ringing flow, Morning check-in | Records, Stats, Morning |
| `SleepSession` (Phase 8) | Sleep tracker | Sleep report |

| Not in SwiftData | Where | Why |
|---|---|---|
| Settings (24h, onboarding done…) | `@AppStorage` | small key-value data |
| Premium status | StoreKit 2 entitlements | Apple is the source of truth |
| Photos for photo mission | Files in Application Support | keeps the database small |
| Alarm sounds | App bundle (`Alarm/Resources/Sounds`) | AlarmKit plays them from the bundle |
| Backup alarm IDs | Calculated (`AlarmKitScheduler.backupID`) | nothing to keep in sync |
