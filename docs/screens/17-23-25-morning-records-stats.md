# Screens #17 Morning check-in · #23 Morning panel · #24 Records · #25 Stats: brief & review guide

**Phase 5** · on `development`

## What they do
- **Morning check-in (#17):** on the "You're up!" success screen, a row of 5 faces (😫 → 🤩). Tapping one saves your
  mood on today's wake-up record. Tap another face to change it (also possible later on the Morning tab).
- **Morning panel (#23):** the Morning tab, now real:
  - greeting for the time of day + **streak** card ("4 day streak", "Best ever: 6 days" underneath)
  - **Today** card: when you were up, snoozes, mission time, and the mood row ("How do you feel?" / change it)
  - **Next alarm** card
  - **This week** chart: what time you were up each day
  - **Line of the day** (20 original lines, one per day)
  - rows to **Records** and **Stats**
- **Records (#24):** a month calendar. Each day is coloured: **sunrise gradient** = up first time, **amber** = snoozed,
  **red** = rang but never finished. Tap a day to see its wake-ups. ‹ › to change month (not into the future).
- **Stats (#25):** 7 / 30 days switch · 4 tiles (average up time, % finished, snoozes, average mission time) ·
  charts for wake-up time, snoozes per day and mood.

Weather (planned for #23) is **not** included: WeatherKit needs the final bundle ID and a capability switched on in
the Apple Developer portal. It moves to Phase 7 with the other bundle-ID items.

## Connection map
```
RingingViewModel.finish() → phase = .success → SuccessView(mood:, onMood:)
  tap 🙂 → RingingViewModel.setMood(.good)
         → WakeRecordRepository.setMood(_:forRecordID:) → save() → refresh() → entries updated

ScreenFactory.makeRoot(.morning) → MorningView(MorningViewModel(records:, alarms:, coordinator:))
  reads records.entries      (live [WakeEntry], refreshed inside every write: single source of truth)
  reads alarms.nextAlarm(after:)
  WakeStats.currentStreak / bestStreak / dailyPoints(days: 7) → WakeTimeChart
  DailyQuote.forDay(.now)
  Records / Stats rows → coordinator.show(.records / .stats)
       → morningPath.append → ScreenFactory.makeScreen(for: MorningRoute)
            → RecordsView(RecordsViewModel(records:))   → WakeStats.byDay + status(of:)
            → StatsView(StatsViewModel(records:))       → WakeStats.dailyPoints(days: 7|30) + rates
```

## Files, in reading order
1. `Models/Mood.swift`: the 5 moods (stored as Int 1…5 in `WakeRecord.moodRawValue`)
2. `Features/Morning/Logic/WakeStats.swift`: `WakeEntry` (value snapshot) + every calculation. **Start here.**
3. `Features/Morning/Logic/DailyQuote.swift`
4. `Repositories/WakeRecordRepository.swift`: `entries`, `setMood`, the Debug `addSampleHistory`
5. `Repositories/AlarmRepository.swift` → `nextAlarm(after:)` (moved here so the List AND Morning can use it)
6. `Features/Ringing/ViewModels/RingingViewModel.swift` → `setMood` · `Views/SuccessView.swift` → `moodPicker`
7. `Features/Morning/ViewModels/MorningViewModel.swift` → `Views/MorningView.swift` → `Views/WakeTimeChart.swift`
8. `Features/Records/ViewModels/RecordsViewModel.swift` → `Views/RecordsView.swift`
9. `Features/Stats/ViewModels/StatsViewModel.swift` → `Views/StatsView.swift`
10. `Coordinator/Routes.swift` (`MorningRoute`) → `AppCoordinator.show(_ route: MorningRoute)` → `RootView` → `ScreenFactory`
11. Tests: `RiseUpTests/MorningAndSleepTests.swift` (suites "Wake statistics", "Morning check-in")

## Data
| Reads | Writes |
|---|---|
| `WakeRecord` (through `WakeRecordRepository.entries` as `WakeEntry` values) | `WakeRecord.moodRawValue` (check-in) |
| `WakeAlarm` (next alarm, through `AlarmRepository.alarms`) | Debug only: sample wake-ups ("Add sample data") |

No schema change: `moodRawValue` was planned in SchemaV2 from the start.

## Design decisions (WHY)
- **`WakeStats` is a `nonisolated enum` of pure functions** with `now:` and `calendar:` parameters. Tests can
  pass a fixed date and a UTC calendar, so they give the same answer in every time zone.
- **A streak survives until tonight:** at 5 a.m., before your alarm, yesterday still counts. Otherwise everyone
  would see "0 days" every morning until they got up.
- **A day counts as "up" if ANY wake-up finished.** If you gave up once and then finished the backup alarm,
  the day is still yours.
- **The repository keeps `entries` as values**, the same rule as `AlarmRepository.alarms`: screens never hold a
  database object that could be deleted under them.
- **Charts plot time of day as a Date on one reference day**, so the axis says "6:30 AM" in the user's own 12/24h
  style. Swift Charts draws dates top-down, so **higher = earlier**, which suits a wake-up chart.
- **Mood x-axis is fixed to the whole range**, so one mood dot doesn't fill the chart alone.

## Debug helpers
Records and Stats have **"Add sample data (Debug)"** (only in Debug builds) to fill 30 days of history.

## Exercises
1. Add a 6th mood? No: moods are stored as numbers. **Never** change the existing raw values. Instead, change the
   emoji of `.okay` in `Mood.swift` and see it everywhere.
2. **TRY:** add your own line to `DailyQuote.all`.
3. Add a tile to Stats: "best streak" (hint: `WakeStats.bestStreak`).
