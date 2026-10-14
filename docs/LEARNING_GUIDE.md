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

## Learned in Phase 3 + 4
| Concept | In one sentence | See it in |
|---|---|---|
| Unit tests (Swift Testing) | `@Test` functions with `#expect`; ⌘U runs them all | `RiseUpTests/` |
| Parameterised tests | `@Test(arguments:)` runs one test for many inputs | `ScheduleCalculatorTests.countdownText` |
| Pure logic = testable logic | Generators and counters with no UI are easy to test 100s of times | `MemoryPatternGenerator`, `SquatRepCounter` |
| `@Sendable` closures | A closure that may run on any thread; needed for background callbacks | `CoreMotionStepCounter.start` |
| `@concurrent` | Run an async function OFF the main thread (Swift 6.2) | `VisionPhotoMatcher.makeFingerprint` |
| `UIViewControllerRepresentable` | Show a UIKit screen (camera, scanner) in SwiftUI | `PhotoCapture.swift`, `BarcodeScanScreen.swift` |
| Delegates + Coordinator | UIKit reports events to a helper object that forwards them to SwiftUI | `CameraPicker.Coordinator` |
| Custom `ViewModifier` | Package a behaviour as `.photoCapture(...)` | `PhotoCapture.swift` |
| `#if targetEnvironment(simulator)` | Code decided at BUILD time for Simulator vs device | `MissionEnvironment` |
| Vision feature prints | Numbers that describe a photo; compare with `distance(to:)` | `VisionPhotoMatcher` |
| VisionKit `DataScannerViewController` | Live camera that reads barcodes / QR codes | `BarcodeScanScreen` |
| CoreMotion: pedometer vs device motion | Steps need permission; raw acceleration doesn't | `StepCounter`, `SquatDetector` |
| Dot product, low-pass filter | Measure along gravity; smooth jittery sensor data | `CoreMotionSquatDetector` |
| `AVSpeechSynthesizer` | The built-in iOS voice | `SpeechTimeAnnouncer` |
| UserDefaults + `@Observable` + `didSet` | Small settings that show on screen and save instantly | `AppSettings` |
| Fallback / graceful degradation | When a feature can't run, offer a fair alternative instead of failing | `MissionView.replacement` |
| Pre-permission screen | Explain before the one-time system popup | `OnboardingView` page 3 |
| `scenePhase` re-check | Refresh when the user returns from the Settings app | `AlarmHealthCheckView` |
| Type erasure (`AnyButtonStyle`) | Wrap different types in one so `?:` can choose between them | `AlarmHealthCheckView.swift` |
| Generic constraint to reach protocol members | Inside `<R: VisionRequest>`, protocol members become visible | (tried for Vision, see HOW_IT_WORKS Bug 8) |

## Learned in Phase 5 + 6
| Concept | In one sentence | See it in |
|---|---|---|
| Swift Charts (`LineMark`, `PointMark`, `BarMark`) | A chart is a list of marks; each mark maps values to x/y | `WakeTimeChart`, `StatsView` |
| Chart scales & axes | `chartXScale(domain:)` sets the visible range; `chartYAxis` styles labels | `WakeTimeChart` |
| Time of day on an axis | Turn "minutes after midnight" into a Date on one reference day | `WakeTimeChart.time(_:)` |
| `Calendar` maths | `startOfDay`, `date(byAdding:)`, `firstWeekday`: never add 86 400 s for "tomorrow" in logic | `WakeStats`, `RecordsViewModel` |
| Injecting `now` and `calendar` | Pass the time in, so tests can freeze it | `WakeStats.currentStreak(_:now:calendar:)` |
| Computed statistics from a live list | No stored copies: screens recompute from `entries`, so they never go stale | `MorningViewModel`, `StatsViewModel` |
| `LazyVGrid` | A grid that lays out cells in columns | `SleepView`, `RecordsView` |
| `AVAudioPlayer` mixing | One player per sound, all playing at once; `numberOfLoops = -1` loops forever | `SleepSoundPlayer` |
| Fades | `setVolume(_:fadeDuration:)` changes volume smoothly | `SleepSoundPlayer.toggle/remove` |
| `AVAudioSession` `.playback` | Plays in Silent mode and while locked | `SleepSoundPlayer.activateSession` |
| Background modes | `UIBackgroundModes: audio` keeps the app running while it plays | `Config/Info.plist` |
| Audio interruptions | iOS tells you when a call stops your audio | `SleepSoundPlayer.init` |
| Now Playing + remote commands | Lock-screen title and Play/Pause buttons | `SleepSoundPlayer.updateNowPlaying` |
| Local notifications | `UNCalendarNotificationTrigger(repeats: true)` = every day at a time | `NotificationBedtimeReminder` |
| `TimelineView(.periodic)` | Redraw every second for a countdown | `SleepPlayerView.playButton` |
| `safeAreaInset(edge:)` | Pin a bar to an edge and let the scroll content end above it | `SleepView` |
| `Duration.formatted(.time(pattern:))` | "12:34" from a number of seconds | `SleepPlayerViewModel.remainingText` |
| Custom `Binding(get:set:)` | Connect a control to ViewModel methods instead of a property | `SleepPlayerView` sliders, `SleepView` toggle |
| Loudness (RMS) normalisation | Scale every sound to the same average level | `Tools/generate_sleep_sounds.py` |
| `AxisMarks(values:)` + `AxisContentBuilder` | Put axis labels at exact positions; share one axis between charts | `ChartDays` in `WakeTimeChart.swift` |
| CoreGraphics drawing | Paths, gradients and clipping: how the app icon is drawn | `Tools/generate_app_icon.swift` |
| App icon appearances | One 1024 px icon each for normal, dark and tinted Home Screens | `Assets.xcassets/AppIcon.appiconset` |

## Learned in Phase 7 (launch readiness)
| Concept | In one sentence | See it in |
|---|---|---|
| `AVCaptureSession` | The live camera; we start/stop it ourselves on a background queue | `CameraSession` |
| `withCheckedContinuation` | Turn a callback ("call me when done") into `await` | `CameraSession.start/capturePhoto` |
| `nonisolated` + `@unchecked Sendable` | A class that deliberately works off the main actor, protected by its own queue | `CameraSession` |
| ImageIO thumbnails | Shrink a big photo without decoding all of it | `PhotoProcessor.uprightImage` |
| Pre-warming | Do slow setup early, while the user is still reading | `CameraAccess.prepareCamera()` |
| Race conditions with `await` | After every `await`, the world may have changed: re-check | `AlarmKitScheduler.schedule`, `AlarmListViewModel.setEnabled` |
| All-or-nothing | On a partial failure, undo the parts that worked | `AlarmKitScheduler.schedule` |
| `NotificationCenter` publishers | React to system events like a time-zone change | `RootView` `.onReceive` |
| Audio interruptions | Phone calls pause audio; resume when they end | `AudioService.init` |
| Graceful failure | Never `fatalError` in production; recover and tell the user | `AppDependencies.openDatabase` |
| `@ScaledMetric` | A size that grows with the user's text size | `RepeatDaysPicker.chipSize` |
| Reduce Motion | `accessibilityReduceMotion`: skip endless animations when it's on | `RingingView`, `SleepView`, `AppLogo` |
| 44-pt tap targets | Apple's minimum comfortable touch size | `NeonToggleStyle`, editor buttons |
| Debug vs Release | `#if DEBUG` code vanishes in the App Store build; build both | `AlarmListView` toolbar |
| Privacy manifest | `PrivacyInfo.xcprivacy`: tracking, data and API reasons for App Review | `Alarm/PrivacyInfo.xcprivacy` |
| Launch screen | `UILaunchScreen` + a colour asset = no white flash | `Config/Info.plist` |
| Karplus–Strong, FM, bell partials | Classic ways to synthesise plucked strings, electric piano and bells | `Tools/generate_sounds.py` |

## Learned building alarm wallpapers (#32)
| Concept | In one sentence | See it in |
|---|---|---|
| `Canvas` + `GraphicsContext` | Draw shapes, gradients and layers yourself, GPU-fast | `Features/Wallpapers/Renderers/` |
| `TimelineView(.animation)` | Redraw every frame; pauses when off-screen | `LiveWallpaperView` |
| Procedural animation | Everything is a pure function of time: nothing stored, nothing leaks | `WallpaperKit` LEARN |
| Hash "random" | `sin(i × big) × big`, keep the fraction: random-looking but repeatable | `WallpaperMath.random` |
| 3D projection | screen = centre + direction / distance | `HyperspaceRenderer` |
| Blend modes | `.plusLighter` adds light; `.destinationOut` erases; `.sourceIn` paints inside | Aurora, Synthwave, Lava Lamp |
| Metaballs | blur + alpha threshold = blobs that melt together | `LavaLampRenderer` |
| `MeshGradient` | colours blended across a moving grid of points | `BreatheWallpaper` |
| Integrals in code | speed changes smoothly when time is the area under the speed curve | `WallpaperEnergy.clock` |
| `VersionedSchema` upgrade | copy the schema, add the field, add a lightweight stage, move typealiases | `SchemaV3`, migration test |
| `NSCache` | an in-memory cache that empties itself when memory is low | `FileWallpaperStore` |
| `preparingForDisplay()` | decode an image in the background, not on the first frame | `FileWallpaperStore.decode` |
| `.photosPicker` modifier | system photo library without camera permission | `WallpaperPickerView` |
| `@Entry` environment values | an app-wide value every view (and sheet) can read | `DeveloperTools.swift` |
| `ImageRenderer` | turn a SwiftUI view into an image (we used it to inspect wallpapers) | HOW_IT_WORKS "look at what you draw" |

## Learned building the Scene Player (#33)
| Concept | In one sentence | See it in |
|---|---|---|
| `.fullScreenCover(isPresented:)` | a full-screen layer driven by a Bool in the ViewModel | `WallpaperPickerView` |
| `.id(value)` + `.transition` | a new id = a new view, so SwiftUI fades the old one out and the new one in | `ScenePlayerView` |
| `DragGesture().onEnded` | read where the finger ended: a sideways swipe | `ScenePlayerView` |
| Wrap-around index | `(index + delta + count) % count` never goes below 0 or past the end | `WallpaperPickerViewModel.step` |
| Looping audio | `AVAudioPlayer.numberOfLoops = -1` repeats until stopped | `AudioService.previewLooping` |
| `.contentTransition(.symbolEffect(.replace))` | SF Symbols morph (▶︎ → ⏸, ♡ → ♥) | `ScenePlayerView` controls |
| `.sensoryFeedback` | a haptic when a value changes, no extra code | `ScenePlayerView` |
| Result structs | send back several answers at once (`WallpaperChoice`: wallpaper + optional sound) | `Wallpaper.swift` |
| Harmonic & noise synthesis | sum of overtones = an instrument; shaped noise = rain, surf, breath | `Tools/generate_sounds.py` |
| Testing string names | `UIImage(systemName:)` returns `nil` for a typo the compiler can't see | test `symbolsExist` |

## Learned building the Wake-up guarantee (#34) and widgets (#31)
| Concept | In one sentence | See it in |
|---|---|---|
| Dead man's switch | keep pushing a deadline while you're alive; stop pushing and it fires | `RingingViewModel` keep-alive |
| `scenePhase` | is the app in front, inactive or in the background? | `RingingView`, `RootView` |
| Serial async queue | each Task awaits the previous one, so jobs never interleave | `AlarmKitScheduler.serially` |
| Version counter | bump on cancel; a busy job compares and gives up | `AlarmKitScheduler.chainVersions` |
| Inferring state | iOS doesn't say "it rang", so read it from what's left (the backups) | `AlarmScheduleCalculator.isWakeUpPending` |
| WidgetKit timeline | entries with dates; iOS draws each at its time, even with the app closed | `NextAlarmProvider` |
| `Text(date, style: .relative)` | a countdown iOS keeps updating without waking the widget | `Countdown` |
| App Groups | a folder + UserDefaults shared by the app and its extension | `Config/*.entitlements`, `WidgetShared` |
| `containerBackground(for: .widget)` | the widget's background (a picture, or clear on the lock screen) | `NextAlarmWidget` |
| `Link` vs `widgetURL` | parts of a widget open different links; small widgets have one | `MediumView`, `SmallView` |
| URL schemes + `.onOpenURL` | `riseup://…` opens the app on a specific screen | `DeepLink`, `RootView` |
| `AnyLayout` | switch between HStack and VStack without repeating the children | `UpcomingRow` |
| `AVAudioSession.outputVolume` | read (never set) the media volume | `AudioService`, volume hint |

## Learned building themes (#35)
| Concept | In one sentence | See it in |
|---|---|---|
| Dynamic colours | `UIColor { traits in … }` gives a different colour in light and dark, chosen while drawing | `Color.adaptive` in `Theme.swift` |
| `.preferredColorScheme` | forces light/dark for a window or a presentation (`nil` = follow the iPhone) | `RiseUpApp`, `RingingView` |
| `.environment(\.colorScheme, …)` | makes one part of the screen think it's in dark mode | widgets |
| `.id(value)` to rebuild | a new id throws a view tree away and builds it fresh | `RiseUpApp` `.id(palette)` |
| Semantic tokens | name colours by role (`accent`, `onAccent`), not by look (`neonPink`) | `Theme.Colors` |
| HSB colour maths | change brightness/saturation to derive a deeper shade | `Color.accent` |

