# Phase 0 · Foundation: brief & review guide

## What Phase 0 delivers
The app's skeleton: design system, database, alarm engine, navigation, and two debug tools.
There are no "real" user screens yet. Tabs show good-looking "Coming in Phase N" placeholders.

## Reading order (about 2–3 hours, take breaks)
Read each file top to bottom. Every `LEARN:` comment explains a concept; every `WHY:` explains a decision.
Write anything unclear in `docs/LEARNING_LOG.md`.

1. `CLAUDE.md`: the rules of the project
2. `docs/ARCHITECTURE.md`: the big picture (come back to it often)
3. **App start**
   1. `Alarm/App/RiseUpApp.swift`
   2. `Alarm/App/AppDependencies.swift`
4. **Design System** (open each file's `#Preview` in Xcode with ⌥⌘↩)
   1. `DesignSystem/Theme.swift`
   2. `DesignSystem/Typography.swift`
   3. `DesignSystem/Components/AppBackground.swift`, `GlowCard.swift`, `NeonButtonStyle.swift`, `NeonToggleStyle.swift`, `BigClockText.swift`
5. **Models (SwiftData)**
   1. `Models/Weekday.swift`, `Models/MissionType.swift`
   2. `Models/SchemaV1.swift`: the most important file of the phase
   3. `Models/WakeAlarm+Helpers.swift`
   4. `Models/RiseUpMigrationPlan.swift`, `Models/ModelContainerFactory.swift`
6. **Repository**: `Repositories/AlarmRepository.swift`
7. **Alarm engine**
   1. `Services/AlarmKit/AlarmScheduling.swift` (the protocol)
   2. `Services/AlarmKit/AlarmScheduleCalculator.swift`
   3. `Services/AlarmKit/AlarmKitScheduler.swift`: read the big header comment twice
   4. `Services/AlarmKit/RiseUpAlarmMetadata.swift`, `StartMissionIntent.swift`, `MockAlarmScheduler.swift`
8. **Navigation**
   1. `Coordinator/Routes.swift`
   2. `Coordinator/AppCoordinator.swift`
   3. `Coordinator/AlarmLaunchRouter.swift`
   4. `Coordinator/ScreenFactory.swift`
   5. `Coordinator/RootView.swift`
9. **Screens**
   1. `Features/Shared/ComingSoonView.swift`
   2. `Features/Settings/Views/SettingsHomePlaceholderView.swift`
   3. `Features/Debug/…`: Lab ViewModel + View, Design Gallery
   4. `Features/Ringing/…`: placeholder ViewModel + View

## Your hands-on tasks (in this order)

### Task 1 · Create the widget extension (needed for alarms to show on an unlocked phone)
1. In Xcode: **File → New → Target…**
2. Choose **iOS → Widget Extension** → Next.
3. Product Name: **`RiseUpWidgets`**
   - **Uncheck** "Include Configuration App Intent"
   - **Check** "Include Live Activity"
   - **Uncheck** "Include Control" (if shown)
4. Finish. If asked "Activate RiseUpWidgets scheme?", click **Don't Activate**. We keep running the main app.
5. Tell Claude "widget target created". Claude replaces the template code with the AlarmKit
   Live Activity UI, shares the needed files, and sets the extension's iOS version to 26.0.

### Task 2 · Create the unit test target
1. **File → New → Target…** → **iOS → Unit Testing Bundle** → Next.
2. Product Name: **`RiseUpTests`**, Testing System: **Swift Testing**, Target to be Tested: **Alarm**.
3. Finish, then tell Claude. Claude writes tests for the schedule calculator, backup IDs and repository.

### Task 3 · Run on your iPhone
1. Connect the iPhone with a cable (or same Wi-Fi after the first time).
2. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
3. In Xcode's toolbar choose the **Alarm** scheme and your iPhone, then press **⌘R**.
4. First time only: on the iPhone, **Settings → General → VPN & Device Management** → trust your developer certificate.

### Task 4 · Run the spike
Follow `docs/SPIKE_RESULTS.md` and fill in the blanks.

## Exercises (do them yourself, then tell Claude to check)
1. **Design tokens:** in `Theme.swift` change `neonPink` to `Color(hex: 0x00E5FF)`. Run, open
   Settings → Design Gallery and see what changed. Then change it back.
2. **Backup chain:** in `AlarmKitScheduler.swift` change `backupOffsetsInMinutes` to `[1, 2, 3]`.
   In the Lab, create a mission alarm and count the backups in the list. Change it back.
3. **Coordinator practice (the important one):** add an "About RiseUp" screen under Settings → Developer:
   - add `case about` to `SettingsRoute` in `Routes.swift`
   - in `ScreenFactory.makeScreen(for: SettingsRoute)` return
     `ComingSoonView(title: "About", systemImage: "info.circle.fill", phase: 4, message: "Made by Salman")`
   - add an `onOpenAbout` closure + row in `SettingsHomePlaceholderView`, and wire it in `ScreenFactory.makeRoot`
   - The compiler will guide you: a `switch` that's missing a case is an error. That's Swift helping you.

## Done when
- [ ] You've read every file above and logged your questions
- [ ] Tasks 1–3 completed
- [ ] Spike results filled in
- [ ] Exercises 1–3 done
→ Then we merge `phase-0-foundation` into `main` and start Phase 1 (Alarm List).
