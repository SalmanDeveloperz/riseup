# Screens #14 Ringing · #15 Missions · #16 Success: brief & review guide

**Phase 2** · on `development`

## What it does
One full-screen flow that runs a whole wake-up:
```
.ringing ──(Start Mission)──▶ .mission(0) → .mission(1) … ──▶ .success
.ringing ──(I'm up)─────────────────────────────────────────▶ .success
.ringing ──(Snooze, if allowed)──▶ screen closes, rings again in N minutes
```
- **Ringing (#14):** title, a huge gradient clock with a breathing glow, the date. RiseUp plays the alarm sound
  itself, starting quiet and getting louder (15 s ramp).
  - Mission alarm: mission chips + **Start Mission**.
  - Plain alarm: **I'm up** + **Snooze N min · X left**, which respects the snooze limit.
- **Missions (#15):** Math (number pad), Typing (letters turn green as you type them right), and Shake
  (a progress ring plus haptics). While you work, the alarm is **quiet**. Stop for 15 seconds and it **comes back**
  with a red "Still there?" banner.
- **Success (#16):** confetti, "You're up!", the wake-up time, mission time, missions and snoozes. **Start my day** closes it.

## How the screen opens (3 ways)
```
① Lock screen "Start Mission"  → StartMissionIntent → AlarmLaunchRouter → RootView .onChange
② App opened while alarm rings → RootView scenePhase .active → AlarmSyncService.sync()
                                  → ringingAlarmID() → found one
③ Alarm List banner "Finish your mission" → AlarmListViewModel.resumeMission()
        all three → AppCoordinator.presentRinging(alarmID:) → fullScreen = .ringing(id)
                  → RootView .fullScreenCover → ScreenFactory → RingingView(RingingViewModel)
```

## Connection map
```
RingingView ── owns ──► RingingViewModel
  .onAppear → start()
      ├─► AlarmRepository.fetch(id:) → RingInfo snapshot (title, missions, sound, snooze)
      ├─► AlarmScheduling.stopRinging(alarm)        (iOS's alarm quiet…)
      ├─► AudioPlaying.startAlarm(sound, rampUp:)   (…ours loud)
      └─► WakeRecordRepository.openRecord(...)      (history row)
  Start Mission → startMissions() → quiet + 15 s idle watchdog
      MissionView → Math/Typing/ShakeMissionViewModel
          onInteraction → userInteracted()   (keeps it quiet)
          onComplete    → missionFinished()  (next, or finish)
  Snooze → AlarmScheduling.scheduleSnooze(minutes:) → close
  finish()
      ├─► AlarmScheduling.missionCompleted(alarm)  (cancel backups + snooze; re-arm tomorrow)
      ├─► quick alarm → delete · one-time → switch off
      ├─► WakeRecord: dismissedAt, missionSeconds, missionsCompleted
      └─► phase = .success → SuccessView → close() → AppCoordinator.dismissFullScreen()
```

## Files, in reading order
1. `Features/Ringing/ViewModels/RingingViewModel.swift`: the state machine (`Phase`), then `start()`, `finish()`, the watchdog
2. `Features/Ringing/Views/RingingView.swift`: one `switch` on `phase`
3. `Features/Missions/Views/MissionView.swift`: the mission "router" (and why `.id(mission.id)` matters)
4. `Features/Missions/ViewModels/MathMissionViewModel.swift` → `Views/MathMissionView.swift`
5. `Features/Missions/ViewModels/TypingMissionViewModel.swift` → `Views/TypingMissionView.swift`
6. `Features/Missions/ViewModels/ShakeMissionViewModel.swift` → `Services/Motion/ShakeDetector.swift`
7. `Features/Ringing/Views/SuccessView.swift` + `DesignSystem/Components/ConfettiView.swift` (`Canvas` + `TimelineView`)
8. `Services/Audio/AudioService.swift`: the alarm loop, ramp and mute
9. `Repositories/WakeRecordRepository.swift` + `Models/SchemaV2.swift` (`WakeRecord`)
10. `Services/AlarmKit/AlarmKitScheduler.swift`: `stopRinging`, `scheduleSnooze`, `missionCompleted`, `hasPendingMission`

## Data
| Reads | Writes |
|---|---|
| `WakeAlarm` + its `MissionConfig`s → copied into `RingInfo` | `WakeRecord` (opened on ring, finished on success; snoozes counted) |
| | `WakeAlarm.isEnabled = false` (one-time) or deleted (quick alarm) |

## Design decisions (WHY)
- **RiseUp plays its own sound.** "Start Mission" silences iOS's alarm, which would otherwise ring over the mission.
  From then on the app must keep you awake.
- **Quiet while active, loud when idle.** A mission you can do half-asleep and then abandon is useless.
  The 15-second watchdog brings the alarm back.
- **Snooze only for alarms without missions.** A mission alarm's whole point is that you can't skip it.
- **The mission lock.** While the backup chain may still ring (mission not done), the Alarm List and the editor
  refuse to switch off, delete or edit that alarm. Otherwise turning it off would be an easy way to skip the
  mission. The list shows a "Finish your mission" banner instead.
- **One record per wake-up.** Snoozing reopens the same `WakeRecord` (it's reused if unfinished and under 3 h old),
  so stats count wake-ups, not rings.
- **`Close (debug)`** exists only in Debug builds (`#if DEBUG`), so testing can never get stuck.

## How to try it
- **Simulator:** Alarm List → ⚡ → 1 min → wait. RiseUp opens the Ringing screen by itself. Or use the Debug Lab's mission test.
- **iPhone (the real test):** lock the phone, wait for the alarm, tap **Start Mission** (or tap Stop and
  watch the backups ring 1, 2, 3, 5 and 8 minutes later until you finish the mission).

## Exercises
1. **TRY:** set `RingingViewModel.idleSecondsBeforeAlarmReturns` to 5. Start a mission and stop touching the screen.
2. Add a fourth stat tile to `SuccessView` (e.g. the alarm title). Where does the data come from? (`WakeSummary`.)
3. Change the confetti `pieceCount` to 300. Then turn on Settings → Accessibility → Reduce Motion. What happens, and why?
