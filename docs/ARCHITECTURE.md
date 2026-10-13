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
│ Model (@Model in SchemaV2)   │
└──────────────────────────────┘
```

| Layer | Folder | Rule |
|---|---|---|
| App | `Alarm/App` | Creates `AppDependencies` + `AppCoordinator`, injects them via `.environment` |
| Coordinator | `Alarm/Coordinator` | All navigation. `ScreenFactory` builds every screen + ViewModel |
| Design System | `Alarm/DesignSystem` (+ `Shared/DesignSystem/Theme.swift`) | Colours, fonts, reusable components. No business logic |
| Features | `Alarm/Features/<Feature>/{Views,ViewModels}` | One folder per feature |
| Repositories | `Alarm/Repositories` | Only place that touches `ModelContext` |
| Services | `Alarm/Services` | System APIs behind protocols |
| Models | `Alarm/Models` | SwiftData schema + plain value types |
| Shared | `Shared/` | Compiled into BOTH the app and the widget extension. Only small types + colours |
| Widget extension | `RiseUpWidgets/` | Lock screen / Dynamic Island alarm UI (a separate program iOS runs) |
| Tools | `Tools/` | Scripts that are NOT part of the app (e.g. the sound generator) |
| Tests | `RiseUpTests/` | Swift Testing unit tests (run with ⌘U, shared `Alarm` scheme) |

## 2. Startup sequence

```
RiseUpApp
 ├─ AppDependencies.live()
 │    ├─ ModelContainerFactory.make()      → SwiftData database (SchemaV2; V1 → V2 migration)
 │    ├─ AlarmRepository(mainContext) + WakeRecordRepository(mainContext)
 │    ├─ AlarmKitScheduler()
 │    ├─ AlarmSyncService(repository, scheduler)
 │    ├─ AudioService() + SpeechTimeAnnouncer()
 │    ├─ MissionServices(shake, steps, squat, photoMatcher)   ← Vision on iPhone, pixels in the Simulator
 │    └─ AppSettings()                                         ← UserDefaults
 ├─ AppCoordinator()
 └─ RootView  (.environment(dependencies), .environment(coordinator))
      ├─ TabView: Alarms | Morning | Sleep | Settings   ← coordinator.selectedTab
      │    Alarms ↔ coordinator.alarmsPath, Settings ↔ coordinator.settingsPath
      ├─ .sheet(item: coordinator.sheet)             sound picker · quick alarm · mission picker
      ├─ .fullScreenCover(item: coordinator.fullScreen)   ringing → missions → success
      ├─ .onChange(settings.hasCompletedOnboarding) → coordinator.presentOnboarding
      ├─ .onChange(AlarmLaunchRouter.pendingAlarmID) → coordinator.presentRinging
      └─ .onChange(scenePhase) → alarmSync.sync() → ringing alarm? → coordinator.presentRinging

RiseUpWidgets (separate program, started by iOS when an alarm needs its Live Activity)
 └─ RiseUpWidgetsBundle → AlarmLiveActivity (lock screen + Dynamic Island)
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
  │     → RootView → coordinator.presentRinging → Ringing screen (app plays the sound now)
  │     → mission solved → scheduler.missionCompleted(alarm)
  │          → cancel today's backups + snooze → arm backups for next occurrence
  ├─ "Stop" (skips mission) → backups ring at 06:31, 06:32, … until the mission is done
  │     (meanwhile the alarm is locked: hasPendingMission → can't switch off / delete / edit)
  └─ app opened any other way → RootView sync → ringingAlarmID() → Ringing screen

Plain alarm (no missions): Ringing screen → "I'm up", or "Snooze" (limited)
  → scheduler.scheduleSnooze → one `.fixed` system alarm, ID = snoozeID(alarm.id)

Quick alarm: `.fixed(fixedFireDate)` → rings once → deleted (in finish(), or by the next sync)
```

**iOS limits behind this design** (see `docs/SPIKE_RESULTS.md`):
- The system Stop button/swipe can't be hidden, and swipe-dismiss does NOT call `stopIntent`.
- On an unlocked phone the alarm is shown as a Live Activity rendered by OUR widget extension. No extension means no UI.

## 5. Data map

| Stored in SwiftData | Written by | Read by |
|---|---|---|
| `WakeAlarm` (time, repeat days, label, enabled, sound, snooze, wake-up check, `fixedFireDate` for quick alarms, `wallpaperID` (V3)) | Alarm Editor, List toggle/delete, Quick Alarm, Sync, Ringing (one-time off / quick delete), Lab | List, Editor, Ringing, Sync |
| `MissionConfig` (type, difficulty, repetitions, order, **textPayload** = barcode, **dataPayload** = photo fingerprint + thumbnail) | Editor Save via `AlarmRepository.replaceMissions` (from Mission Picker drafts + registrations) | Editor, Ringing → missions |
| `WakeRecord` (alarm, ring start, dismissed at, snoozes, missions, mission seconds, mood) | `RingingViewModel` via `WakeRecordRepository` (mood: success screen + Morning tab) | Morning, Records, Stats through `WakeRecordRepository.entries` (`WakeEntry` values) |
| `SleepSession` (Phase 8) | Sleep tracker | Sleep report |

| Not in SwiftData | Where | Why |
|---|---|---|
| Settings (onboarding done, Time Pressure, default sound/snooze, goal, bedtime reminder, last sleep mix) | `AppSettings` → UserDefaults | small key-value data |
| The sleep mix that is playing now (sounds, volumes, timer) | `SleepSoundPlayer` (in memory, long-lived service) | must outlive the screens; nothing to keep after a restart except "last mix" |
| Bedtime reminder | One pending `UNNotificationRequest` (`riseup.bedtime`) in iOS | iOS delivers it even when the app is closed |
| Premium status | StoreKit 2 entitlements | Apple is the source of truth |
| Photos for photo mission | Files in Application Support | keeps the database small |
| Alarm sounds | App bundle (`Alarm/Resources/Sounds`) | AlarmKit plays them from the bundle |
| Sleep sounds | App bundle (`Alarm/Resources/SleepSounds`) | played by `AVAudioPlayer`, looping |
| Wallpaper photos | Files in Application Support/Wallpapers (`WallpaperStore`) | big pictures stay out of the database |
| Live wallpapers | Code (`Features/Wallpapers/Renderers`) | nothing to store or download |
| Saved (♥) wallpapers | `AppSettings.savedWallpapers` (UserDefaults) | a short list of strings, a preference |
| Backup, snooze and wake-up-check alarm IDs | Calculated (`backupID` / `snoozeID` / `wakeUpCheckID`) | nothing to keep in sync |
| Alarm metadata for the lock screen | Inside AlarmKit's `AlarmAttributes` (iOS stores it) | the widget extension can't open our database |
