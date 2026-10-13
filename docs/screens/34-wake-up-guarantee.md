# #34 Wake-up guarantee: brief & review guide

**Phase 7+** · on `development` · no database change (one new switch in `AppSettings`)

## The problem (found by Salman on his iPhone)
The alarm rang with the screen off; one press on **volume down** and it was gone. That's iOS, not a bug in
RiseUp: AlarmKit lets **Stop, the side button and the volume buttons** silence any app's alarm, and no app
can block that (Apple's rule, Alarmy included). Also, alarms *without* missions had no way into the app from
the lock screen, so their wallpaper and sound were never seen.

## What it does
- **Every alarm gets a re-ring chain** (not only mission alarms), while **Settings → Wake-up guarantee** is on
  (default): backups ring **+30 s, 1, 1.5, 2, 3, 5, 8 and 12 min** after each ring. A button press only silences
  the one ringing now; 30 seconds later the next one rings. They stop only after **"I'm up"** or a finished
  mission **inside RiseUp**. A snooze moves the chain behind the snooze ring.
- **Every ring has a second button that opens RiseUp**: "Start Mission", or **"Wake up"** for alarms without
  missions → the Ringing screen with the alarm's **wallpaper (60 fps, energy rising) and sound**, full screen.
- **While the Ringing screen is open** (and RiseUp is in front) it pushes the chain 75 s ahead every 30 s, so
  iOS's alert never pops over the wallpaper or a mission. Lock the phone or leave the app → it rings again within
  about a minute (a "dead man's switch").
- **"Your volume is low"** hint on the Ringing screen: inside RiseUp the alarm plays at the *media* volume, which
  Apple doesn't let apps change.
- The Alarm List's banner is now **"Finish waking up"**, and the lock applies to every guarded alarm.

## What iOS doesn't allow (said honestly)
- iOS draws the ringing alarm on the lock screen itself (title, buttons, our tint colour). No app can put a
  wallpaper or animation there. The wallpaper appears the moment RiseUp opens ("Wake up" / "Start Mission").
- No app can stop the buttons from silencing an alarm. The guarantee makes it come back instead.

## Connection map
```
schedule(alarm) → main ring (+ "Wake up"/"Start Mission" → StartMissionIntent)
               → isGuarded? (missions || AppSettings.guaranteesWakeUp)
               → serially { scheduleBackupChain(after: next ring) }   8 fixed backups
Volume button → iOS silences the ringing one → +30 s: next backup "Still in bed? Tap Wake up"
"Wake up" → StartMissionIntent → AlarmLaunchRouter → RootView → Ringing screen
  RingingViewModel.start() → stopRinging · startAlarm(sound) · startKeepAlive()
     every 30 s while scenePhase == .active → scheduler.holdBackupChain(alarm)   (first backup = now + 75 s)
     app goes to background → stopKeepAlive()                                  (iOS rings within ~1 min)
  "I'm up" / last mission → finish() → stopKeepAliveAndWait() → scheduler.wakeUpCompleted(alarm)
                                       (chain cancelled; tomorrow's armed for repeating alarms)
Settings switch → SettingsViewModel.guaranteesWakeUp → AlarmSyncService.rescheduleAll()
```

## Files, in reading order
1. `Services/AlarmKit/AlarmKitScheduler.swift`: header "HOW RISEUP ALARMS WORK", `backupOffsets`, `isGuarded`,
   `holdBackupChain`, `serially` + `chainVersions` (read the WHYs), `hasPendingWakeUp`
2. `Services/AlarmKit/AlarmScheduleCalculator.swift`: `isWakeUpPending` (the pure rule) + its tests
3. `Features/Ringing/ViewModels/RingingViewModel.swift`: MARK Keep-alive, `isVolumeLow`
4. `Features/Ringing/Views/RingingView.swift`: `scenePhase`, `volumeHint`
5. `Services/Settings/AppSettings.swift` (`guaranteesWakeUp`) → `SettingsViewModel` → `SettingsView`
6. `Services/Sync/AlarmSyncService.swift`: `rescheduleAll`, Rule 2
7. Tests: `ScheduleCalculatorTests` (pending rule), `RingingFlowTests.keepAliveHoldsTheChain`

## Design decisions (WHY)
- **Pending is read from iOS, not stored:** iOS doesn't tell us when an alarm rang. A backup that rings *earlier*
  than the next ring's chain must belong to a ring that already happened. Far-away backups (time-zone change)
  don't count.
- **Chain jobs run in a line (`serially`)** and every cancel bumps a version: the keep-alive, the sync, a snooze
  and "I'm up" can touch the same chain at the same moment; this keeps them from mixing.
- **`finish()` waits for a running hold** before cancelling, or the hold could re-arm the chain after "I'm up".
- **iOS's own Snooze button is gone for guarded alarms:** backups would ring in the middle of it. Snooze lives on
  the Ringing screen (with its limit), and the chain follows it.
- **The intent keeps its old name (`StartMissionIntent`)** although it now also does "Wake up": iOS stores it
  inside alarms that are already scheduled; renaming it could break them.

## Test on the iPhone (locked, silent, app killed)
1. Plain alarm in 2 min, lock the phone. When it rings press **volume down** → it rings again ~30 s later.
2. Tap **Wake up** → the wallpaper and sound appear full screen. Wait 3 minutes on that screen: no system alert.
3. Press the side button to lock the phone on the Ringing screen → it rings again within about a minute.
4. "I'm up" → silence. Settings → switch the guarantee off → a plain alarm stops for good with Stop.

## Exercises
1. **TRY:** `AlarmKitScheduler.backupOffsets = [30, 60]` and watch the AlarmKit Lab list.
2. **TRY:** `RingingViewModel.keepAliveSeconds = 10`; the Lab shows the backups moving.
3. Explain in your own words why `stopKeepAliveAndWait()` must `await` (hint: Bug 44 in HOW_IT_WORKS).
