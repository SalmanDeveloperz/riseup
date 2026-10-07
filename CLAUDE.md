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

## Comment conventions (required in every file)
- File header: what the file is, its LAYER, who uses it, what DATA it touches.
- `///` doc comments on types and non-trivial methods. `// MARK: -` sections.
- `// LEARN:` explains a Swift/SwiftUI concept where it is used (beginner level, plain English).
- `// TRY:` a safe change Salman can make to experiment.
- `// WHY:` reasons for non-obvious decisions, especially iOS-limitation workarounds.

## Workflow
- One branch per phase (`phase-N-name`), one commit per screen. Build must have **zero warnings**.
- For each screen: write `docs/screens/NN-name.md` brief → build → update `docs/ROADMAP.md` status.
- Verify alarms on a real iPhone (locked, silent, app killed). The Simulator is for UI only.
- Build check: `xcodebuild -scheme Alarm -destination 'generic/platform=iOS Simulator' build`
