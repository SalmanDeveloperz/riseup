# RiseUp Learning Guide

A glossary of every concept used in the code, with **where to see it**. Search the project for
`LEARN:` to find the explanations inside the code (in Xcode: ⇧⌘F, then type `LEARN:`).

## Swift language
| Concept | In one sentence | See it in |
|---|---|---|
| `struct` vs `class` | Structs are copied values (Views, small data); classes are shared references (ViewModels, models) | `BigClockText.swift` vs `AppCoordinator.swift` |
| `enum` with raw values | A fixed list of choices, each with a stored value (`"math"`, `1`) | `MissionType.swift`, `Weekday.swift` |
| `enum` as namespace | An enum with no cases is a folder for constants | `Theme.swift` |
| `extension` | Add abilities to an existing type | `Color(hex:)` in `Theme.swift`, `WakeAlarm+Helpers.swift` |
| `protocol` | A contract: what something can do, not how | `AlarmScheduling.swift` |
| Generics `<Content: View>` | One type that works with many types | `GlowCard.swift` |
| Closures `() -> Void` | A function passed around as a value | `SettingsHomePlaceholderView.swift` |
| `guard … else { return }` | Leave early when something's missing | `AlarmKitScheduler.schedule` |
| `defer` | Run code right before leaving a function | `AlarmLaunchRouter.consumePendingAlarmID` |
| `try` / `try?` / `do-catch` | Error handling | `AlarmRepository`, `AlarmKitScheduler.cancel` |
| `typealias` | A short name for a type | bottom of `SchemaV2.swift` |
| `[weak self]` | A closure that doesn't keep its owner alive | `AlarmEditorViewModel.chooseSound` |
| `switch` with associated values | Pull data out of an enum case (`case .mission(let index)`) | `RingingViewModel.currentMission`, `AlarmActivityInfo` |
| `#if DEBUG` | Code that exists only in Debug builds | `RingingView` "Close (debug)" |

## Concurrency (Swift 6)
| Concept | In one sentence | See it in |
|---|---|---|
| `async` / `await` | Functions that wait without freezing the UI | `AlarmKitScheduler.schedule` |
| `Task { }` | Start async work from a button | `AlarmLabView` buttons |
| `.task { }` | Async work tied to a view's lifetime | `AlarmLabView` |
| `for await` (AsyncSequence) | Loop over values that arrive over time | `AlarmLabViewModel.observeSystemAlarms` |
| Main actor / `nonisolated` | Main = UI thread (our default); `nonisolated` = usable from any thread | `Weekday.swift`, `StartMissionIntent.perform` |
| `Sendable` | Safe to pass between threads; why we use `AlarmManager.shared` directly | WHY note in `AlarmKitScheduler.swift` |
| `nonisolated extension` | Each extension gets the main-actor default separately; opt out per extension | `MissionDraft.swift` (`extension MissionType`) |
| `MainActor.assumeIsolated` | "I promise this callback already runs on the main thread" | `CoreMotionShakeDetector.start` |
| A loop in a `Task` + cancel | A background timer you can stop | `RingingViewModel.startWatchdog` |

## SwiftUI
| Concept | In one sentence | See it in |
|---|---|---|
| `@State` | A view's own memory that survives redraws | `AlarmLabView.viewModel` |
| `@Observable` | Class whose property changes redraw views that read them | `AppCoordinator`, all ViewModels |
| `@Environment` | Read shared objects injected higher up | `RootView` |
| `@Bindable` | Make `$bindings` to an @Observable object | `RootView` |
| `@ViewBuilder` | Return different views from `if`/`switch` | `ScreenFactory` |
| `ButtonStyle` / `ToggleStyle` | Restyle built-in controls | `NeonButtonStyle.swift`, `NeonToggleStyle.swift` |
| `TabView` + `Tab` | Bottom tab bar | `RootView` |
| `NavigationStack(path:)` | Push screens driven by an array | `RootView` (Settings tab) |
| `.fullScreenCover(item:)` | Cover everything when a value is non-nil | `RootView` |
| `TimelineView` | Redraw on a schedule (clock) | `ComingSoonView` |
| `.sensoryFeedback` | Haptics | `NeonToggleStyle` |
| `#Preview` | Live canvas preview in Xcode (⌥⌘↩ to show) | bottom of every View file |

## SwiftData
| Concept | In one sentence | See it in |
|---|---|---|
| `@Model` | Turns a class into a database table | `SchemaV1.swift` |
| `@Attribute(.unique)` / `.externalStorage` | Column options | `SchemaV1.swift` |
| `@Relationship(deleteRule: .cascade)` | Linked rows, deleted together | `WakeAlarm.missions` |
| `ModelContainer` / `ModelContext` | Database file / scratchpad of changes | `ModelContainerFactory`, `AlarmRepository` |
| `FetchDescriptor` + `#Predicate` | A typed database query | `AlarmRepository.fetch(id:)` |
| `VersionedSchema` + `SchemaMigrationPlan` | Safe upgrades after release | `SchemaV1.swift`, `RiseUpMigrationPlan.swift` |
| In-memory container | Throwaway DB for previews/tests | `AppDependencies.preview()` |

## Apple frameworks
| Framework | Used for | See it in |
|---|---|---|
| AlarmKit | System alarms that ring when silent/locked/closed | `AlarmKitScheduler.swift` |
| App Intents | "Start Mission" button action | `StartMissionIntent.swift` |
| ActivityKit / WidgetKit | Alarm UI on lock screen / Dynamic Island (widget extension) | `RiseUpWidgets/AlarmLiveActivity.swift` |
| AVFoundation | Play sounds (`AVAudioSession`, `AVAudioPlayer`, looping, volume fade) | `AudioService.swift` |
| CoreMotion | Accelerometer for the Shake mission | `ShakeDetector.swift` |

## Patterns
| Pattern | Why we use it | See it in |
|---|---|---|
| MVVM | Views stay simple; logic is testable | any `Features/*/ViewModels` |
| Coordinator | Screens don't know about each other | `Coordinator/` |
| Repository | One place for database code | `AlarmRepository.swift` |
| Dependency Injection | Swap real/fake services | `AppDependencies.swift` |
| Design tokens | Change the look in one file | `Theme.swift` |

## System design (learned while building the Alarm List)
Full stories in `docs/HOW_IT_WORKS.md` Part 4.

| Concept | In one sentence | See it in |
|---|---|---|
| Single source of truth | One owner holds the data; everyone else reads it, nobody keeps a copy | `AlarmRepository.alarms`, `AlarmListViewModel.rows` |
| Value snapshot (view state) | Views get plain structs copied from the database objects, so they can never touch a deleted object | `AlarmRow.swift` |
| Computed property chaining | `rows` → `repository.alarms` → each alarm; Observation tracks the whole chain | `AlarmListViewModel.rows` |
| Race condition | Two async jobs interleave at `await`, and one sees half-finished work | `AlarmKitScheduler.isScheduling`, reconcile loop |
| Reconcile / sync | Compare two systems (our DB vs iOS) and fix the differences | `AlarmListViewModel.reconcileWithSystemAlarms` |
| Optimistic update + rollback | Change the UI first, undo it if the real work fails | `AlarmListViewModel.setEnabled` |
| The 5 connection mechanisms | Environment, init injection, closures, observation, bindings | `HOW_IT_WORKS.md` Part 1 |

## Learned while building the Alarm Editor
| Concept | In one sentence | See it in |
|---|---|---|
| Draft / form state | Edit a value copy; write it to the database only on Save | `AlarmDraft.swift` |
| `@Binding` | A value owned by someone else that this view may change | `RepeatDaysPicker.selection` |
| Binding to a computed property | `get`/`set` lets a control edit hour/minute through a `Date` | `AlarmEditorViewModel.time`, `.label` |
| `DatePicker(.wheel)` | The iOS time wheel; respects 12/24-hour automatically | `AlarmEditorView.timeCard` |
| `@FocusState` | Which text field has the keyboard; set it to `false` to hide it | `AlarmEditorView` |
| Protocol extension | Write a method once; every conforming type gets it | `AlarmScheduling.requirePermission()` |
| `ButtonStyleConfiguration.role` | Lets a style react to `role: .destructive` | `GhostButtonStyle` |
| `.toolbar(.hidden, for: .tabBar)` | Hide the tab bar on a focused screen | `AlarmEditorView` |
| Object lifetime (strong references) | An object lives as long as someone holds it; a context doesn't hold its container | `AlarmRepository.container` |

## Learned in Phase 1 (rest) + Phase 2
| Concept | In one sentence | See it in |
|---|---|---|
| Schema migration (V1 → V2) | Add a new schema version + a lightweight stage instead of editing a shipped model | `SchemaV2.swift`, `RiseUpMigrationPlan.swift` |
| Sync service | A service that coordinates a repository and a system service | `AlarmSyncService.swift` |
| `scenePhase` | Know when the app comes to the front | `RootView` |
| `.sheet(item:)` + callbacks | Present by setting a value; results come back through a stored closure | `AppCoordinator.presentSoundPicker`, `RootView` |
| Child coordinator | A flow inside a sheet owns its own small navigation path | `MissionPickerViewModel.path` |
| `presentationDetents` + `safeAreaInset` | Half-height sheets with a button that is always visible | `QuickAlarmView` |
| State machine (`enum Phase`) | One value says which step of a flow we're in; the View `switch`es on it | `RingingViewModel.Phase`, `RingingView` |
| `.id(_:)` to reset state | A new id = a brand-new view with fresh `@State` | `RingingView` → `MissionView` |
| Stored vs computed (randomness) | Random/expensive results are stored and refreshed on purpose | `MissionPickerViewModel.refreshSample` |
| `Canvas` + `TimelineView(.animation)` | Draw many shapes every frame (confetti) | `ConfettiView.swift` |
| `.symbolEffect` / `.contentTransition(.numericText())` | Built-in SF Symbol and number animations | `ShakeMissionView`, `SuccessView` |
| `accessibilityReduceMotion` | Respect the user's "Reduce Motion" setting | `ConfettiView` |
| Widget extension + shared folder | A second program in the app; shares source files, not objects | `RiseUpWidgets/`, `Shared/` |
| Live Activity (`ActivityConfiguration`, `DynamicIsland`) | System UI drawn by our extension from data iOS stores | `AlarmLiveActivity.swift` |
| `Text(date, style: .timer)` | A countdown iOS updates by itself (widgets can't run timers) | `AlarmTimingText` |
