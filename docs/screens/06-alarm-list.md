# Screen #6 · Alarm List: brief & review guide

**Phase 1 · chunk 1** · on `development`

## What it does
The first screen of the Alarms tab:
- Header card: "Rings in 7h 20m · Thu 6:30 AM · Gym", or "No alarms on"
- One glowing card per alarm: time, label + repeat days, mission icons, on/off switch
- Tap a card → Alarm Editor (edit mode, placeholder for now)
- "+" button / "Create your first alarm" → Alarm Editor (create mode)
- Swipe left → Delete
- Empty state when there are no alarms
- 🐞 menu (debug builds only): "Add sample alarms"
- Every time it appears: re-reads the database and fixes alarms that no longer match iOS

## Connection map
```
RootView ── Alarms tab ── NavigationStack(path: coordinator.alarmsPath)
   └─ ScreenFactory.makeRoot(.alarms)
        └─ AlarmListView ─────────── owns ──► AlarmListViewModel
             │  reads rows / nextAlarm()          │
             ├─ NextAlarmHeaderView(NextAlarmInfo) ├─► AlarmRepository  (alarms, refresh, save, delete)
             ├─ AlarmCardView(AlarmRow) ×N        ├─► AlarmScheduling  (schedule, cancel, isScheduling)
             └─ FloatingAddButton                 ├─► AlarmScheduleCalculator (next ring time)
                                                  └─► AppCoordinator.showAlarmEditor → pushes .editor
```

## Files, in reading order
1. `Coordinator/Routes.swift`: new `AlarmsRoute.editor(alarmID:)`
2. `Coordinator/AppCoordinator.swift`: new `alarmsPath`, `showAlarmEditor`, `popAlarms`
3. `Repositories/AlarmRepository.swift`: now `@Observable` with a live `alarms` list (read the "single source of truth" note)
4. `Services/AlarmKit/AlarmScheduling.swift` + `AlarmKitScheduler.swift`: new `isScheduling(_:)` (race-condition guard)
5. `Models/WakeAlarm+Helpers.swift`: new `repeatSummary`
6. `Features/Alarms/ViewModels/AlarmRow.swift`: value snapshots (read the LEARN block)
7. `Features/Alarms/ViewModels/AlarmListViewModel.swift`: the brain; read every `←` / `→` comment
8. `DesignSystem/Components/FloatingAddButton.swift`
9. `Features/Alarms/Views/NextAlarmHeaderView.swift`
10. `Features/Alarms/Views/AlarmCardView.swift`
11. `Features/Alarms/Views/AlarmListView.swift`
12. `Coordinator/ScreenFactory.swift` + `RootView.swift`: how the screen is plugged in
13. `DesignSystem/Components/NeonToggleStyle.swift`: `labelsHidden` support + animation fix

Then read `docs/HOW_IT_WORKS.md` Part 3 (Traces A–D) and Part 4 (the three bugs).

## Data
| Reads | Writes |
|---|---|
| `AlarmRepository.alarms` (via `rows`, `nextAlarm`) | `WakeAlarm.isEnabled` (switch, reconcile) |
| iOS scheduled alarm IDs (reconcile) | deletes `WakeAlarm` (swipe) |
| | inserts sample alarms (debug menu) |

## Navigation
- **In:** Alarms tab root (`ScreenFactory.makeRoot(for: .alarms)`)
- **Out:** `AlarmsRoute.editor(alarmID: nil)` from "+", `AlarmsRoute.editor(alarmID: id)` from a card tap

## How to try it (Simulator is fine for this screen)
1. Run → Alarms tab shows "No alarms yet".
2. 🐞 → "Add sample alarms" → three grey (off) cards appear.
3. Switch "Gym" on → permission popup the first time → the card glows; the header shows the countdown.
4. Swipe "Power nap" left → Delete.
5. Tap a card / "+" → the editor placeholder opens; back returns to the list.

## Exercises
1. **Read the trace:** follow Trace B in `HOW_IT_WORKS.md` with Xcode open, clicking into every
   function named. Write in `LEARNING_LOG.md` which of the 5 mechanisms each step uses.
2. **Change the countdown format** in `NextAlarmHeaderView.countdownText`: show "7 hours 20 minutes"
   instead of "7h 20m". (Only this one function changes. That's why it's a separate `static func`.)
3. **Add a sample alarm:** in `AlarmListViewModel.addSampleAlarms()` add a "Prayer" alarm at 5:00
   every day with a Typing mission. Check the card shows "Every day" and the keyboard icon.
4. **Break it on purpose (important!):** in `AlarmListViewModel.reconcileWithSystemAlarms`, remove
   `&& !scheduler.isScheduling(alarm)`. Run, open the Lab, tap "Create mission alarm" and switch to
   the Alarms tab immediately. You'll see the alarm switch itself off. Put the line back. You've
   now seen a race condition with your own eyes.

## Known limits (planned)
- Editor is a placeholder → next chunk (Screen #8).
- One-time alarms that already rang stay "on" until the list is opened → Phase 2 moves the
  reconcile to app launch (`AlarmSyncService`).
- Alarms that are OFF in the database but still scheduled in iOS (only possible after a bug)
  aren't cleaned up yet → Phase 2 `AlarmSyncService`.
- While a mission's backups are ringing, the user can still switch the alarm off or delete it
  → Phase 2 "mission lock".
