# Screen #7 · Quick Alarm: brief & review guide

**Phase 1** · on `development`

## What it does
A half-height sheet for "ring in N minutes", made for naps:
- A big gradient number ("10 min") with −/+ buttons (1-minute steps, 5-minute steps above 30)
- **Rings at 5:23 PM** under it, updating live
- 8 preset chips: 1, 5, 10, 15, 20, 30, 45 min, 1 h
- **Start** stays pinned at the bottom, even in the half-height sheet
- Opened from the ⚡ button on the Alarm List (also from the empty state)

After it rings, the quick alarm **deletes itself** (AlarmSyncService rule 1), so the list doesn't fill up with old naps.

## Connection map
```
AlarmListView ⚡ button
  → AlarmListViewModel.quickAlarmTapped()
  → AppCoordinator.presentQuickAlarm() → sheet = .quickAlarm
  → RootView .sheet(item:) → ScreenFactory.makeScreen(for: .quickAlarm)
       └─ QuickAlarmView ── owns ──► QuickAlarmViewModel
                                       ├─► AlarmScheduling.requirePermission
                                       ├─► AlarmRepository.insert(WakeAlarm with fixedFireDate)
                                       ├─► AlarmScheduling.schedule → AlarmKitScheduler → `.fixed(date)`
                                       └─► AppCoordinator.dismissSheet()
```

## Files, in reading order
1. `Models/SchemaV2.swift`: the new `fixedFireDate` field (and why it needed a schema version)
2. `Models/WakeAlarm+Schedule.swift`: `isQuickAlarm`, `nextFireDate(after:)`
3. `Features/QuickAlarm/ViewModels/QuickAlarmViewModel.swift`
4. `Features/QuickAlarm/Views/QuickAlarmView.swift`: `presentationDetents`, `safeAreaInset`
5. `Services/AlarmKit/AlarmKitScheduler.swift`: search `fixedFireDate`: quick alarms use `.fixed(date)`, not `.relative`

## Data
| Reads | Writes |
|---|---|
| — | New `WakeAlarm` (label "Quick alarm", `fixedFireDate` = exact moment, no repeat) |

## Design decisions (WHY)
- **`.fixed(date)` instead of hour:minute.** "Ring in 1 minute" at 17:02:40 must ring at 17:03:40, not at 17:03:00.
  A `.relative` schedule only knows hours and minutes.
- **Why a schema change:** the exact moment has to survive an app restart, so it's stored (`fixedFireDate`).
  Adding a field to a released model = new `SchemaV2` + a migration stage (see `RiseUpMigrationPlan`).
- **Start pinned with `safeAreaInset(edge: .bottom)`:** in the half-height sheet the button was cut off.
  `safeAreaInset` keeps it visible and pushes the content up instead.

## How to try it (Simulator is fine)
1. Tap ⚡ → **1 min** → **Start**. A "Quick alarm" card appears and the header says "Rings in 1m".
2. Wait. It rings, and RiseUp opens the Ringing screen by itself. Tap **I'm up**.
3. Back on the list: the quick alarm is gone.

## Exercises
1. **TRY:** swap the 45-minute preset for 90 (`QuickAlarmViewModel.presets`). Does the "1 h 30 min" text work?
2. Make the default 20 minutes instead of 10. Which one property do you change?
3. Read `AlarmSyncService` rule 1. What would happen if quick alarms were *switched off* instead of deleted?
