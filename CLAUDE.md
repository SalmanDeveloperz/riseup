# RiseUp — project rules

RiseUp is an Alarmy-style mission alarm clock for iPhone. The owner (Salman) is a beginner
who learns by reviewing every file, so **code clarity and learning comments are part of the product**.

Start every session by reading `docs/ROADMAP.md` (what's done / next) and this file.
`README.md` is the front page; `docs/TALKING_POINTS.md` explains the app in plain language (keep it current
when a feature, framework or number changes); `docs/DEBUGGING_GUIDE.md` teaches tracing (keep its labs' file +
function names valid when renaming).

## Tech
- iOS 26.0+, iPhone only, portrait. System appearance by default; Settings offers System/Light/Dark + 5 colour palettes (#35). Swift 6 language mode, default actor isolation = MainActor.
- SwiftUI + SwiftData + AlarmKit. MVVM + Coordinator.
- Xcode project uses file-system-synchronized folders: new files under `Alarm/` join the app target automatically.
- Two targets: `Alarm` (the app) and `RiseUpWidgets` (widget extension: lock screen / Dynamic Island alarm UI).
  Files in `RiseUpWidgets/` belong to the extension; files in `Shared/` belong to BOTH (keep it tiny: shared types + `Theme`).
  The widget's Info.plist is `Config/RiseUpWidgets-Info.plist`.
- Third target: `RiseUpTests` (Swift Testing). The shared `Alarm` scheme runs it (⌘U /
  `xcodebuild test -scheme Alarm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`).
- Permission texts (camera, motion) are build settings (`INFOPLIST_KEY_NS…UsageDescription`) in the app target.
- Extra Info.plist keys Xcode can't set via build settings go in `Config/Info.plist`.

## Architecture rules
- **View → ViewModel → Repository/Service → Model.** Views never use `@Query` or `modelContext`.
- ViewModels are `@Observable final class`, owned by the View with `@State`, created in `Coordinator/ScreenFactory.swift`.
- Navigation only through `AppCoordinator` (routes in `Coordinator/Routes.swift`). Views get closures or a ViewModel; they never push screens themselves.
- Services have a protocol (`AlarmScheduling`) + real impl + mock (`MockAlarmScheduler`) for previews/tests. Only `AlarmKitScheduler`, `StartMissionIntent`, `Shared/RiseUpAlarmMetadata`, the widget extension and the debug Lab may `import AlarmKit`.
- SwiftData models live inside the latest schema (`SchemaV4`, VersionedSchema) with typealiases at the bottom of that file; older schemas are frozen. Changing a model after release = new schema version + migration stage. Never rename stored enum raw values.
- The database file lives in the App Group folder (SwiftData picks it because of the entitlement). `StoreRelocation` moves
  pre-widget installs there before the container opens. Never change the store name or `ModelConfiguration` location
  without a matching move + test.
- Our alarm model is `WakeAlarm` (Apple already owns the name `Alarm`).
- Call `AlarmManager.shared` directly at each use (don't store it): Swift 6 Sendable rule.
- Use `Theme.*` tokens and DesignSystem components; no raw colours/numbers in screens.
- Themes (#35): colours are role tokens (`accent`, `accentDeep`, `accentWarm`, `accentCool`, `Gradients.brand`), each
  adaptive light/dark. Text/icons ON an accent fill use `Theme.Colors.onAccent`, never `textPrimary`. The Ringing
  flow, Scene Player, widgets and Live Activity are always dark. Never rename a `ColorPalette` case (saved).
- Pure value types (enums/structs without UI) are marked `nonisolated`.
- **Single source of truth:** `AlarmRepository.alarms` and `WakeRecordRepository.entries` are the live lists
  (refreshed inside every write). ViewModels read them through computed properties and never keep their own copy.
- State that must outlive a screen (the sleep-sound mix and its timer) lives in a long-lived service from
  `AppDependencies` (`SleepSoundPlayer`), never in a ViewModel.
- **Views receive value snapshots** (e.g. `AlarmRow`, `NextAlarmInfo`), never `@Model` objects.
  Actions come back with an ID; the ViewModel looks up the live object. (A deleted @Model read by a View crashes.)
- Code that compares our database with iOS must skip alarms where `scheduler.isScheduling(alarm)` (race condition).
  Database ↔ iOS sync lives in `AlarmSyncService` (runs on launch, foreground and list load).
- Once + days (#36): `WakeAlarm.extraOnceDate` is the exact moment of ONE extra ring (system ID `onceRingID`), scheduled
  only via `separateOnceRing` (never a double ring on a chosen weekday). A passed date means "done": clear it, never
  roll it forward.
- Missions (#38): the editor's `MissionCard` stays second (right under the time). One-tap tiles add
  `MissionDraft.defaults`; Photo/QR (`needsSetup`) open the picker on their setup. Cards and widgets add missions via
  `AlarmListViewModel.addMission(toAlarm:)` (saves straight away, same lock/rollback rules as the switch).
- Sleep mini player (#39): `RootView` shows `SleepMiniPlayer` on the tab bar while `SleepMiniPlayerViewModel.isVisible`
  (sounds on, not on the Sleep tab); `tabViewBottomAccessory(isEnabled:)` on iOS 26.1+, a glass overlay on 26.0.
- Text fields that a ViewModel clears after a match: give the field a new `.id` and tag writes with what they
  belong to (`TypingMissionViewModel.type(_:forPhrase:)`); never rely on resetting the bound value alone.
- Wake-up lock: while `scheduler.hasPendingWakeUp(alarm)` is true, the alarm can't be switched off, deleted or edited.
- Re-ring chain: mission alarms, and every alarm while `AppSettings.guaranteesWakeUp` is on, get backups at
  `AlarmKitScheduler.backupOffsets`. Every chain change goes through `serially` (one job at a time per alarm).
  The Ringing screen holds the chain only while the app is active; always `stopKeepAliveAndWait()` before
  `wakeUpCompleted` / snooze. Never rename `StartMissionIntent` (iOS stores it inside scheduled alarms).
- Sheets go through `AppCoordinator.sheet` (`SheetRoute`); results come back via stored `@ObservationIgnored` callbacks.
- Your own sounds (#37): `SoundChoice` = `.builtIn(AlarmSound)` | `.custom(CustomSound)`; files are
  `Library/Sounds/riseup_custom_<UUID>.caf` (made by `SoundClipMaker`, listed by `CustomSoundLibrary`). Never change
  `CustomSound.filePrefix`. A missing custom file must become iOS's tone (`AlarmSoundRule`), never a silent alarm.
- Alarm sounds are generated by `Tools/generate_sounds.py`, sleep sounds by `Tools/generate_sleep_sounds.py`;
  every bundled asset is listed in `docs/ASSETS.md`. Never rename a shipped sound file (names are saved).
- Date logic takes `now:` and `calendar:` parameters (pure `nonisolated` functions) so tests can fix both.
- Missions get sensors through `MissionServices` (one bundle). Every sensor/camera mission MUST call `onUnavailable`
  when it can't run on a real device (→ Math fallback in `MissionView`); never leave a user unable to stop an alarm.
- Simulator vs device: use `MissionEnvironment.isSimulator` / `CameraAccess.usesRealCamera`. Simulator gets
  "Simulate…" buttons, the photo library and `PixelPhotoMatcher`; real devices never do.
- Callbacks from Apple frameworks that run on background threads must be `@Sendable` closures that hop back with
  `Task { @MainActor in … }` (Swift 6 runtime crash otherwise).
- Small preferences live in `AppSettings` (UserDefaults), not SwiftData.
- Tracing: key junctions call `Trace.log(.area, "Type.method() → what happens next")` (`Services/Logging/Trace.swift`,
  os.Logger `.debug`). Add one to every new feature's entry point; never log user text (alarm titles).
- Camera: missions use `.photoCapture` → `CameraScreen` → `CameraSession` (background queue). Never
  `UIImagePickerController` (it froze the app). Slow hardware/file work never runs on the main thread.
- After every `await` in code that schedules alarms, re-check that the alarm still exists and is still wanted.
- RiseUp is free: no StoreKit, no paywall. Never `fatalError` in production code paths.
- Wallpapers: renderers are pure functions of (time, energy); `energy` changes LOOKS only, speed comes from
  `WallpaperEnergy.clock`. Debug-only UI also checks `@Environment(\.showsDeveloperTools)` (Developer mode).
- Every `LiveWallpaper` has a `signatureSound`; the picker returns a `WallpaperChoice` (wallpaper + optional sound).
  The Scene Player shares `WallpaperPickerViewModel`. New SF Symbol names must pass the `symbolsExist` test.
- Widgets read ONLY `Shared/WidgetSnapshot.swift` data from the App Group `group.com.testProject.Alarm` (in both
  entitlement files). The app writes it via `WidgetBridge` (RootView: after sync + on background). Widget taps are
  `riseup://` links → `DeepLink` → `AppCoordinator.open`. The alarm's Live Activity stays picture-free.

## Comment conventions (required in every file)
- File header: what the file is, its LAYER, what DATA it touches, and a **CONNECTIONS** block:
  `← CREATED BY / OWNED BY / CALLED BY / USED BY` and `→ CALLS / NAVIGATES / READS/WRITES`.
- At call sites that cross a layer, add a short arrow comment, e.g. `// → coordinator.showAlarmEditor → editor is pushed`.
- `///` doc comments on types and non-trivial methods. `// MARK: -` sections.
- `// LEARN:` explains a Swift/SwiftUI concept where it is used (beginner level, plain English).
- `// TRY:` a safe change Salman can make to experiment.
- `// WHY:` reasons for non-obvious decisions, especially iOS-limitation workarounds.

## Git workflow (since 2026-10-07)
- Only two long-lived branches: `main` (milestones only) and `development` (all ongoing work).
- Work happens on `development` (or a short `feature/<name>` branch from it, merged back by PR, then deleted).
  `development` → `main` only by PR at milestones. Never merge directly into `main`.
- Always `git pull` the branch you start from **before** creating a new branch from it.
- History note: `main` contains Phase 0 commits + a revert (9676403); `development` starts with
  "Reapply Phase 0" (0912479). So a normal `development` → `main` merge brings all code. Never revert that reapply.
- Salman runs git commands that touch GitHub (push, PRs, branch deletion) personally; Claude gives exact,
  pre-tested steps and only commits locally.

## Workflow
- One commit per screen. Build must have **zero warnings**.
- Commit messages: plain, no `Co-Authored-By` or any Claude/AI attribution (Salman's explicit request).
- Never commit Salman's own uncommitted experiments unless asked; leave them in the working tree.
- For each screen: write `docs/screens/NN-name.md` brief (with a connection map) → build → update
  `docs/ROADMAP.md` status → add new traces/lessons to `docs/HOW_IT_WORKS.md`.
- Verify alarms on a real iPhone (locked, silent, app killed). The Simulator is for UI only.
- Build check: `xcodebuild -scheme Alarm -destination 'generic/platform=iOS Simulator' build`
- Before a milestone also build Release: `xcodebuild -scheme Alarm -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- Launch steps and store texts: `docs/APP_STORE.md`.
