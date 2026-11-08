# Screen #8 · Alarm Editor: brief & review guide

**Phase 1 · chunk 2** · on `development`

## What it does
Create a new alarm ("+" on the list) or edit one (tap a card):
- Big time wheel with a live **"Rings in 7h 20m"** under it
- Repeat days: 7 round chips + presets (Once / Weekdays / Weekends / Every day)
- Label (max 30 characters, with a counter)
- Mission and Sound rows: shown, but their pickers arrive later (Sound = next chunk, Missions = Phase 2)
- Snooze on/off, length (1–30 min) and limit (1–10×). Disabled for mission alarms.
- **Save** (asks permission the first time, saves, schedules with iOS, goes back)
- **Cancel** (throws the draft away)
- **Delete Alarm** (edit mode, with a confirmation)

## Connection map
```
AlarmListView "+" / card tap
  → AlarmListViewModel.addAlarmTapped() / alarmTapped(alarmID:)
  → AppCoordinator.showAlarmEditor(alarmID:) → alarmsPath.append(.editor(alarmID:))
  → RootView NavigationStack → ScreenFactory.makeScreen(for: .editor)
       └─ AlarmEditorView ─── owns ──► AlarmEditorViewModel
            │  binds to draft            │
            ├─ DatePicker  ($time)       ├─► AlarmRepository  (fetch(id:), insert, save, delete)
            ├─ RepeatDaysPicker          ├─► AlarmScheduling  (requirePermission, schedule, cancel)
            │   ($draft.repeatDays)      ├─► AlarmScheduleCalculator (Rings in…)
            ├─ TextField ($label)        └─► AppCoordinator.popAlarms() → back to the list
            └─ Toggle/Pickers ($draft.isSnoozeEnabled…)
```

## Files, in reading order
1. `Features/AlarmEditor/ViewModels/AlarmDraft.swift`: why we edit a copy (read the LEARN block)
2. `Features/AlarmEditor/ViewModels/AlarmEditorViewModel.swift`: read the "SAVE FLOW" header, then `save()` step by step
3. `Features/AlarmEditor/Views/RepeatDaysPicker.swift`: `@Binding`
4. `Features/AlarmEditor/Views/AlarmEditorView.swift`
5. `Models/Weekday+Summary.swift`: shared "Weekdays / Mon, Wed" text
6. `Services/AlarmKit/AlarmScheduling.swift`: new `requirePermission()` protocol extension + `AlarmPermissionError`
7. `Services/AlarmKit/AlarmScheduleCalculator.swift`: `countdownText` moved here (used by list header + editor)
8. `Coordinator/ScreenFactory.swift`: `.editor` now builds the real editor
9. `Repositories/AlarmRepository.swift`: new `container` property (Xcode Preview crash fix; read its WHY)
10. `DesignSystem/Components/NeonButtonStyle.swift`: destructive ghost buttons turn red

## Data
| Reads | Writes |
|---|---|
| `WakeAlarm` by ID (edit mode) → copied into `AlarmDraft` | On Save: all draft fields into the `WakeAlarm` (new or existing), `isEnabled = true` |
| | On Delete: removes the `WakeAlarm` (+ cancels its system alarms) |
| Missions (display only) | Missions are left untouched |

## Navigation
- **In:** `AlarmsRoute.editor(alarmID: nil)` = new, `AlarmsRoute.editor(alarmID: id)` = edit
- **Out:** `AppCoordinator.popAlarms()` after Save / Cancel / Delete. The tab bar is hidden while editing.

## Design decisions (WHY)
- **Draft, not live object.** Cancel must leave no trace, and the list behind shouldn't change while you type.
- **Permission before saving.** Saving "on" and *then* asking would leave the database saying "on" while iOS has nothing.
- **Saving turns the alarm on**, like the iOS Clock app.
- **If permission is denied:** the alarm is still saved (you don't lose your work) but switched off, with a clear message.
- **Snooze limit note:** AlarmKit's lock-screen Snooze can't be limited by apps; our ringing screen (Phase 2) will enforce `maxSnoozeCount`.

## How to try it (Simulator is fine)
1. Tap **+** → set 7:15, tap **Weekdays**, type "Gym", **Save** → a glowing card appears.
2. Tap the card → everything is filled in → change to **Weekends** → **Save** → the subtitle changes.
3. Tap the card → **Cancel** → nothing changed.
4. Tap the card → scroll → **Delete Alarm** → confirm → it's gone.

## Exercises
1. **Remove duplicate logic (refactoring):** `WakeAlarm.repeatSummary` in `WakeAlarm+Helpers.swift`
   repeats the logic now in `Weekday.summary(for:)`. Make it one line:
   `var repeatSummary: String { Weekday.summary(for: repeatDays) }`. Build. Nothing should change on screen.
2. **Add a preset:** add `("Mon/Wed/Fri", [.monday, .wednesday, .friday])` to `presets` in
   `RepeatDaysPicker`. Does the summary text say "Mon, Wed, Fri"? Why? (Hint: `Weekday.summary`.)
3. **Trace Save:** with `HOW_IT_WORKS.md` Trace F open, put breakpoints on each numbered step in
   `AlarmEditorViewModel.save()` and step through a save with F6.
4. **Default time:** new alarms start at the current time, so they always say "Rings in 23h 59m".
   Change `AlarmDraft.newAlarm` so a new alarm starts at the *next full hour* instead.
   (Hint: `calendar.nextDate(after:matching: DateComponents(minute: 0), matchingPolicy: .nextTime)`.)

## Known limits (planned)
- Sound picker → next chunk (Screen #13).
- Mission picker → Phase 2 (Screen #9).
- Because the back button is hidden, the edge swipe-back is off too: the only ways out are Cancel and Save.
  (An "unsaved changes" warning isn't needed for that reason.)
