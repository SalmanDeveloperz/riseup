# Screens #26 Settings · #28 Check my alarms · #29 FAQ & Privacy: brief & review guide

**Phase 4** · on `development`

## What they do
- **Settings (#26):** the Settings tab, now real:
  - **Alarms:** Check my alarms, **Time Pressure** switch
  - **New alarms:** default sound (opens the Sound Picker), default snooze length
  - **Help:** Questions & answers, Privacy, Replay intro
  - **Developer** (Debug builds only): AlarmKit Lab, Design Gallery · app version at the bottom
- **Check my alarms (#28), "Why didn't my alarm ring?":** a header (all good / almost there / needs fixing) and one
  card per check. Problems come first, and each has a fix button:
  | Check | Fix |
  |---|---|
  | Alarm permission | Allow (popup) / Open Settings |
  | Any alarm on? | (info) |
  | Every enabled alarm really scheduled in iOS | Repair now (runs a sync) |
  | Mission backups armed | Repair now |
  | Camera allowed (only if a Photo/Barcode mission exists) | Open Settings |
  | Motion allowed (only if a Steps mission exists) | Open Settings |
  | Tips: volume, closing the app, test alarm | Test alarm (opens Quick Alarm) |
  It re-checks when you come back from the Settings app.
- **FAQ (#29):** 9 questions in expandable cards. **Privacy (#29):** what's stored, in plain words.

## Connection map
```
ScreenFactory.makeRoot(.settings) → SettingsView(SettingsViewModel(settings:, coordinator:))
  rows → viewModel.open(.alarmCheck | .faq | .privacy | .alarmKitLab | .designGallery)
       → AppCoordinator.show(route) → settingsPath.append → ScreenFactory.makeScreen(for: SettingsRoute)
  Default sound → AppCoordinator.presentSoundPicker(onPick: → AppSettings.defaultSound)
  Replay intro  → AppSettings.hasCompletedOnboarding = false → RootView → onboarding
AlarmHealthCheckViewModel
  READS: AlarmRepository.alarms, AlarmScheduling (permission, systemAlarms, ringingSystemAlarmIDs, isScheduling),
         CameraAccess.permission, StepCounting.isAvailable
  FIXES: requestPermission · AlarmSyncService.sync() · AppCoordinator.presentQuickAlarm · (View) openURL(Settings)
AlarmEditorViewModel (new alarms) ← AppSettings.defaultSound / defaultSnoozeMinutes
```

## Files, in reading order
1. `Features/Settings/ViewModels/SettingsViewModel.swift`: get/set computed properties as bindings
2. `Features/Settings/Views/SettingsView.swift` + `DesignSystem/Components/SettingsRow.swift`
3. `Features/Settings/ViewModels/AlarmHealthCheckViewModel.swift`: each numbered check
4. `Features/Settings/Views/AlarmHealthCheckView.swift`: `scenePhase` re-check, `AnyButtonStyle` (type erasure)
5. `Features/Settings/Views/FAQView.swift` (why no ViewModel), `PrivacyView.swift`

## Design decisions (WHY)
- **The checker compares the database with iOS**, the same idea as the sync service. The race guard (`isScheduling`)
  applies here too.
- **Fixes, not just warnings.** A red card without a button is frustrating; every fixable problem has one tap.
- **No ViewModel for FAQ/Privacy:** they have no logic. The rule exists for clarity, not for empty files.
- **Time Pressure & defaults live in UserDefaults** (`AppSettings`): small switches, not database rows.

## Before the App Store (Phase 7)
- A public **privacy policy URL** and a **support contact** are required by Apple. They aren't in the app yet
  (we don't invent addresses). Add them to Settings → Help when you have them.

## How to try it
Settings tab → **Check my alarms**. Turn off a permission in the Simulator's Settings app → come back → the card turns red
→ tap **Open Settings**. Try **Repair now** after deleting the app's alarms in the AlarmKit Lab.

## Exercises
1. Add a FAQ item (see the TRY in `FAQItem.all`).
2. Add a new check: "Low Power Mode is on" (hint: `ProcessInfo.processInfo.isLowPowerModeEnabled`) as an `.info` card.
3. **TRY:** change `SettingsViewModel.snoozeOptions` to only `[5, 10]`.
