# #18 Wake-Up Check · Time Pressure · Safety net: brief & review guide

**Phase 3** · on `development`

## What they do
- **Wake-Up Check (#18):** set it in the editor (Off / 3 / 5 / 10 / 15 min). A few minutes after you're up,
  one more alarm rings: **"Wake-up check: are you up?"**. Stopping it (or opening RiseUp) answers it.
  The Success screen says *"Wake-up check in 3 min. Don't go back to bed!"*.
- **Time Pressure:** while you do a mission (the alarm sound is paused then), RiseUp says the time out loud
  when the mission starts and then every minute: *"It's 6:32. Keep going!"*. On/off in Settings.

## Connection map
```
RingingViewModel.finish()
  → scheduler.wakeUpCompleted(alarm)                     (backups off, tomorrow re-armed)
  → alarm.wakeUpCheckMinutes > 0 ?
       → scheduler.scheduleWakeUpCheck(alarm, minutes)   (.fixed alarm, ID = wakeUpCheckID)
  → WakeSummary.wakeUpCheckMinutes → SuccessView note

… N minutes later iOS rings "Wake-up check: are you up?"
  ├─ user taps Stop → done (reacting = awake)
  └─ user opens RiseUp → RootView → AlarmSyncService.sync() rule 4
        → scheduler.stopWakeUpCheckIfRinging(alarm)
     (ringingAlarmID() ignores the check, so the missions DON'T start again)

RingingViewModel watchdog (every second during missions)
  → announceTimeIfDue(): settings.speaksTimeWhileRinging && isQuiet && ≥ 60 s since last
  → TimeAnnouncing.announce(now) → AVSpeechSynthesizer
```

## Files, in reading order
1. `Services/AlarmKit/AlarmScheduling.swift`: `ringingSystemAlarmIDs` vs `systemAlarmIDs`, `scheduleWakeUpCheck`, `stopWakeUpCheckIfRinging`
2. `Services/AlarmKit/AlarmKitScheduler.swift`: point 4 in the header, `wakeUpCheckID`, the two new methods
3. `Services/Sync/AlarmSyncService.swift`: rule 4, and why `ringingAlarmID` uses ringing IDs only
4. `Features/Ringing/ViewModels/RingingViewModel.swift`: `finish()`, `announceTimeIfDue()`
5. `Services/Audio/TimeAnnouncer.swift`
6. `Features/AlarmEditor/Views/AlarmEditorView.swift` → `wakeUpCheckCard`

## Data
| Reads | Writes |
|---|---|
| `WakeAlarm.wakeUpCheckMinutes` (it has existed since SchemaV1, waiting for this feature) | Editor writes it. Nothing new in the database. |
| `AppSettings.speaksTimeWhileRinging` | Settings writes it (UserDefaults) |

## Design decisions (WHY)
- **Why a real AlarmKit alarm for the check:** it rings even if the phone is locked and the app closed,
  exactly when the user might have gone back to bed. A notification could be slept through.
- **Two ID sets:** a ringing wake-up check must NOT open the missions again. So "which IDs mean *do the wake-up*"
  (`ringingSystemAlarmIDs`) is separate from "which IDs belong to this alarm" (`systemAlarmIDs`, used to keep
  alarms during cleanup).
- **Time Pressure only while quiet:** when the alarm is blasting, nobody would hear the voice anyway.
- **No wake-up check for quick alarms** (found while testing): a quick alarm deletes itself right after ringing,
  and its check alarm belongs to it, so the check was cancelled too, even though Success had promised it.
  Now the editor greys the option out for quick alarms (`AlarmEditorViewModel.offersWakeUpCheck`) and
  `finish()` never schedules one for them.

## How to try it
1. **+** → tap the minute wheel to 1–2 minutes from now → (optional: add a Typing mission, Very easy, 1) →
   Wake-up check **After 3 min** → Save. (Not a quick alarm: those can't have a check, see above.)
2. When it rings: open RiseUp → Start Mission → you'll hear the time → type the phrase → Success shows the check note.
3. 3 minutes later "Wake-up check: are you up?" rings.

## Exercises
1. **TRY:** add 20 to `AlarmEditorViewModel.wakeUpCheckOptions`.
2. Add your own phrase to `SpeechTimeAnnouncer.nudges`.
3. Why would it be a bug if `ringingAlarmID()` used `systemAlarmIDs(for:)`? (Hint: what would the check alarm do?)
