# RiseUp — project rules

RiseUp is an Alarmy-style mission alarm clock for iPhone. The owner (Salman) is a beginner
who learns by reviewing every file, so **code clarity and learning comments are part of the product**.

Start every session by reading `docs/ROADMAP.md` (what's done / next) and this file.

## Tech
- iOS 26.0+, iPhone only, portrait, dark-only UI. Swift 6 language mode, default actor isolation = MainActor.
- SwiftUI + SwiftData + AlarmKit. MVVM + Coordinator.
- Xcode project uses file-system-synchronized folders: new files under `Alarm/` join the app target automatically.
- Extra Info.plist keys Xcode can't set via build settings go in `Config/Info.plist`.

## Architecture rules
- **View → ViewModel → Repository/Service → Model.** Views never use `@Query` or `modelContext`.
- ViewModels are `@Observable final class`, owned by the View with `@State`, created in `Coordinator/ScreenFactory.swift`.
- Navigation only through `AppCoordinator` (routes in `Coordinator/Routes.swift`). Views get closures or a ViewModel; they never push screens themselves.
- Services have a protocol (`AlarmScheduling`) + real impl + mock (`MockAlarmScheduler`) for previews/tests. Only `AlarmKitScheduler` (and the debug Lab) may `import AlarmKit`.
- SwiftData models live inside `SchemaV1` (VersionedSchema) with typealiases. Changing a model after release = new schema version + migration stage. Never rename stored enum raw values.
- Our alarm model is `WakeAlarm` (Apple already owns the name `Alarm`).
- Call `AlarmManager.shared` directly at each use (don't store it): Swift 6 Sendable rule.
- Use `Theme.*` tokens and DesignSystem components; no raw colours/numbers in screens.
- Pure value types (enums/structs without UI) are marked `nonisolated`.
- **Single source of truth:** `AlarmRepository.alarms` is the live list (refreshed inside every write).
  ViewModels read it through computed properties and never keep their own copy.
- **Views receive value snapshots** (e.g. `AlarmRow`, `NextAlarmInfo`), never `@Model` objects.
  Actions come back with an ID; the ViewModel looks up the live object. (A deleted @Model read by a View crashes.)
- Code that compares our database with iOS must skip alarms where `scheduler.isScheduling(alarm)` (race condition).

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
