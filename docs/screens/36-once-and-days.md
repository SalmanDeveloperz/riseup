# #36 Once + days: "ring today once, AND every Wednesday"

**Phase 7+** · on `development` · database change: **SchemaV4** adds `WakeAlarm.extraOnceDate: Date?`

## What it does
In the Alarm Editor's repeat row, **Once** can now be combined with weekdays:
- **Once** alone: a one-time alarm (same as before).
- **Wed** alone: every Wednesday (same as before).
- **Once + Wed** (new): ONE extra ring at the next 12:00 (today, or tomorrow if 12:00 has passed), and every
  Wednesday at 12:00 as usual. The row says **"Once + Wed"**, and the editor explains it in a sentence:
  *"Rings once today at 12:00 PM, then every Wed."* (on a Wednesday morning: *"Rings today at 12:00 PM (one of
  your days anyway), then every Wed."*)

Asked for by the lead after negative testing. The cases he will try, and what happens:

| Situation (alarm 12:00, Once + Wed) | Rings |
|---|---|
| Saved Monday 09:00 | Mon 12:00 (extra), then Wed, Wed, Wed… |
| Saved Monday 13:00 (time passed) | Tue 12:00 (extra), then Wed… |
| Saved **Wednesday** 09:00 | Wed 12:00 **once** (the extra ring IS a Wednesday ring), then Wed… |
| Saved **Tuesday 13:00** | Wed 12:00 **once** (tomorrow is a Wednesday anyway), then Wed… |
| Saved at **exactly** 12:00:00 | tomorrow (the same rule as every other alarm: "now" is already too late) |
| Untick every day | plain one-time alarm ("Once" can't stay as an extra without days) |
| Extra ring rang, user taps "I'm up" | `extraOnceDate` cleared, the alarm stays ON for Wednesdays |
| Extra ring rang, user only pressed Stop | the next sync clears it (date passed), Wednesdays go on |
| Opened the editor before 12:00, saved after it rang | NOT re-armed for tomorrow (see Bug 47) |
| Change the time from 12:00 to 07:00 | a new extra ring at the next 07:00 |
| Switch the alarm off and on | the extra ring comes back only if it's still to come |
| Quick alarm / plain "Once" alarm | never get an extra ring |
| Widgets | list the extra ring once, then the Wednesdays, never a double |
| Mission alarm / Wake-up guarantee | the backup chain protects the EXTRA ring too (it follows `nextFireDate`) |

## Connection map
```
AlarmEditorView
  RepeatDaysPicker(alsoOnce: $draft.alsoOnce)   tap "Once" with days → alsoOnce.toggle()
  TimelineView(.everyMinute) → viewModel.onceAndDaysDetail(now:)       "Rings once today at…"
  Save → AlarmEditorViewModel.save()
           alarm.extraOnceDate = resolvedExtraOnceDate(stored:now:)     → AlarmScheduleCalculator.onceRingDate
           → AlarmRepository.save → AlarmKitScheduler.schedule(alarm)
                 scheduleMainAlarm        .relative(12:00, repeats: .weekly([.wednesday]))   ID = alarm.id
                 separateOnceRing(after:) → scheduleOnceRing  .fixed(Mon 12:00)              ID = onceRingID
                 backup chain after nextFireDate (= the extra ring when it's first)
Rings → "I'm up" → RingingViewModel.finish() → extraOnceDate = nil
Pressed Stop only → next launch → AlarmSyncService.sync() rule 5b → extraOnceDate = nil
Lost from iOS     → AlarmSyncService.sync() rule 5a → schedule(alarm) again
```

## Files, in reading order
1. `Alarm/Models/SchemaV4.swift`: `extraOnceDate` (read its WHY: a date, not a Bool) + `RiseUpMigrationPlan.migrateV3toV4`
2. `Alarm/Services/AlarmKit/AlarmScheduleCalculator.swift`: `onceRingDate`, `isCoveredByWeekly`
3. `Alarm/Models/WakeAlarm+Schedule.swift`: `nextFireDate`, `upcomingOnceRing`, `separateOnceRing`
4. `Alarm/Services/AlarmKit/AlarmKitScheduler.swift`: header item 5, `schedule`, `scheduleOnceRing`,
   `ringConfiguration` (LEARN: `sending`), `onceRingID`
5. `Alarm/Services/Sync/AlarmSyncService.swift`: rules 5a and 5b
6. `Alarm/Features/AlarmEditor/ViewModels/AlarmEditorViewModel.swift`: `hasOnceAndDays`, `onceAndDaysDetail`,
   `resolvedExtraOnceDate`, `save()`, `makeDraft`
7. `Alarm/Features/AlarmEditor/Views/RepeatDaysPicker.swift` → `AlarmEditorView.swift`
8. `Alarm/Features/Ringing/ViewModels/RingingViewModel.swift`: `finish()`
9. Tests: `RiseUpTests/OnceAndDaysTests.swift` (17 tests, each named after the case it proves)

## Design decisions (WHY)
- **A date, not a Bool:** `alsoOnce: Bool` couldn't answer "has the extra ring happened yet?". The exact moment
  can: in the future = still to come; in the past = done, ignore it. No timer has to switch anything off.
- **A second iOS alarm, not a change to the weekly one:** AlarmKit has no "weekly + one extra" schedule. The
  extra ring is one more `.fixed` alarm with its own ID (`onceRingID`, worked out from the alarm ID, like the
  backups), so it can be cancelled without touching the weekly one.
- **No double ring:** if the extra ring falls on one of the chosen days at the same time, it isn't scheduled
  separately (`separateOnceRing` returns nil). The weekly alarm already covers it.
- **The next 12:00, never "today only":** after 12:00 it means tomorrow, exactly like a normal one-time alarm.
  The sentence under the row always says which ("today" / "tomorrow").
- **Onboarding keeps the old picker** (no `alsoOnce` binding): a first alarm should stay simple.

## Test on the iPhone
1. New alarm 2 minutes from now, tick **Once + today's weekday + another day** → it rings once in 2 minutes,
   not twice.
2. New alarm 2 minutes from now, **Once + a day that isn't today** → it rings in 2 minutes. Tap "I'm up";
   reopen the alarm: the row says just that weekday, and the alarm is still ON.
3. Same as 2 but only press Stop on the lock screen, then open RiseUp → same result as 2.

## Exercises
1. **TRY:** in `OnceAndDaysTests`, change the test date "Monday 09:00" to "Wednesday 13:00". Predict when the
   extra ring is before you run the test.
2. Put a breakpoint on `scheduleOnceRing` and save a Once + Wed alarm on a Wednesday morning. Why is it never
   hit? (Answer: `separateOnceRing` → `isCoveredByWeekly`.)
3. Read `resolvedExtraOnceDate` and explain in one sentence why it keeps the stored date instead of
   recalculating it every time.
