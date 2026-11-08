# Screens #1–#4 · Onboarding: brief & review guide

**Phase 4** · on `development`

## What it does
A full-screen flow on first launch (and from Settings → Replay intro):
1. **Welcome:** a glowing sunrise, "The alarm you can't sleep through", three promises, **Get started**
2. **Goal:** "What brings you here?" with 4 cards. The choice decides the suggested mission:
   stop snoozing → Math · never late → Memory · morning routine → Typing · move first thing → Squats
3. **Permission:** explains *why* before iOS's one-time "Allow alarms?" popup. If denied, there's an Open Settings button
4. **First alarm:** time wheel (starts 7:00), repeat days (starts Weekdays), "Add the suggested mission" switch,
   **Create my alarm** (pinned at the bottom) or **Skip for now**

Page dots, Back and **Skip** sit at the top. Pages slide left/right in the direction you move.

## Connection map
```
RiseUpApp → RootView
  .onChange(of: settings.hasCompletedOnboarding, initial: true)
     false → AppCoordinator.presentOnboarding()   (never over a ringing alarm)
           → fullScreen = .onboarding → ScreenFactory → OnboardingView(OnboardingViewModel)
OnboardingViewModel
  → AppSettings.wakeGoal / hasCompletedOnboarding
  → AlarmScheduling.requestPermission()          (page 3)
  → AlarmRepository.insert + replaceMissions      (page 4)
  → AlarmScheduling.schedule
  → finish(): hasCompletedOnboarding = true → AppCoordinator.dismissFullScreen()
Settings → "Replay intro" → hasCompletedOnboarding = false → RootView's onChange → onboarding again
```

## Files, in reading order
1. `Services/Settings/AppSettings.swift`: `WakeGoal`, UserDefaults + `didSet`
2. `Features/Onboarding/ViewModels/OnboardingViewModel.swift`: read the pre-permission WHY
3. `Features/Onboarding/Views/OnboardingView.swift`: `.id(page)` + `.transition` (the slide)
4. `Coordinator/RootView.swift` → the onboarding `onChange`; `AppCoordinator.presentOnboarding`

## Data
| Reads | Writes |
|---|---|
| `AppSettings` (goal, defaults) | `AppSettings.wakeGoal`, `hasCompletedOnboarding`; one `WakeAlarm` (+ one `MissionConfig`) |

## Design decisions (WHY)
- **Explain before asking.** iOS shows "Allow alarms?" only once. A "Don't Allow" without context sends users to the
  Settings app forever. One friendly page first = far more "Allow"s.
- **No Photo/Barcode suggestions here:** they need a registration (photo/scan), too much for a first-launch screen.
- **Skip is always visible.** Forcing people through onboarding makes them leave.
- **A flag in UserDefaults, not SwiftData:** it's one yes/no switch (see AppSettings' LEARN).

## How to try it
Settings → **Replay intro**. Or delete the app from the Simulator and run it again.

## Exercises
1. Add a 5th goal ("Sleep less, do more") with its own suggested mission. Which `switch` statements does the compiler point to?
2. **TRY:** make the first alarm start at 6:30 (`OnboardingViewModel.init`).
3. Why does `presentOnboarding()` check `fullScreen == nil`? What would happen without it if an alarm rang on first launch?
