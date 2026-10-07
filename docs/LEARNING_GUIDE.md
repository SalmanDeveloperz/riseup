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
| `typealias` | A short name for a type | bottom of `SchemaV1.swift` |

## Concurrency (Swift 6)
| Concept | In one sentence | See it in |
|---|---|---|
| `async` / `await` | Functions that wait without freezing the UI | `AlarmKitScheduler.schedule` |
| `Task { }` | Start async work from a button | `AlarmLabView` buttons |
| `.task { }` | Async work tied to a view's lifetime | `AlarmLabView` |
| `for await` (AsyncSequence) | Loop over values that arrive over time | `AlarmLabViewModel.observeSystemAlarms` |
| Main actor / `nonisolated` | Main = UI thread (our default); `nonisolated` = usable from any thread | `Weekday.swift`, `StartMissionIntent.perform` |
| `Sendable` | Safe to pass between threads; why we use `AlarmManager.shared` directly | WHY note in `AlarmKitScheduler.swift` |

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
| ActivityKit / WidgetKit | Alarm UI on lock screen / Dynamic Island (widget extension) | `RiseUpWidgets/` (after you create it) |

## Patterns
| Pattern | Why we use it | See it in |
|---|---|---|
| MVVM | Views stay simple; logic is testable | any `Features/*/ViewModels` |
| Coordinator | Screens don't know about each other | `Coordinator/` |
| Repository | One place for database code | `AlarmRepository.swift` |
| Dependency Injection | Swap real/fake services | `AppDependencies.swift` |
| Design tokens | Change the look in one file | `Theme.swift` |
