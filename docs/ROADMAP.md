# RiseUp Roadmap & Progress

Status: ⬜ todo · 🟡 built, waiting for Salman's review · ✅ reviewed & done

Screen numbers (#) match the original feature list. Every screen gets a brief in `docs/screens/`.

---

## Phase 0 — Foundation  ·  branch `phase-0-foundation`
| Item | Status | Notes |
|---|---|---|
| Project settings (iOS 26.0, iPhone, Swift 6, RiseUp name, dark, portrait) | 🟡 | Commit 7ef19fd had set the target to iOS 17.6; raised to 26.0 because AlarmKit requires iOS 26 |
| `Config/Info.plist` with AlarmKit permission text | 🟡 | |
| Design System (Theme, Typography, AppBackground, GlowCard, buttons, toggle, BigClockText) | 🟡 | See Design Gallery screen |
| SwiftData SchemaV1 (`WakeAlarm`, `MissionConfig`) + migration plan + container factory | 🟡 | |
| `AlarmRepository` | 🟡 | |
| `AlarmScheduling` protocol, `AlarmKitScheduler`, `MockAlarmScheduler`, `AlarmScheduleCalculator` | 🟡 | Backup chain included |
| `StartMissionIntent` + `AlarmLaunchRouter` | 🟡 | |
| Coordinator: `AppCoordinator`, `Routes`, `ScreenFactory`, `RootView` (4 tabs) | 🟡 | |
| Debug: AlarmKit Lab, Design Gallery, Ringing placeholder | 🟡 | |
| **Widget extension target `RiseUpWidgets`** (Salman creates it in Xcode) | ⬜ | Required: no alarm UI on an unlocked phone without it |
| **Unit test target `RiseUpTests`** (Salman creates it in Xcode) | ⬜ | Then Claude adds calculator/repository tests |
| Spike experiments A–E on a real iPhone → `docs/SPIKE_RESULTS.md` | ⬜ | |
| Decide final bundle ID (currently `com.testProject.Alarm`) | ⬜ | Must be final before App Groups (Phase 4) / App Store |

## Phase 1 — Alarms core  ·  branch `phase-1-foundation` (stacked on `phase-0-foundation`)
| # | Screen / item | Status |
|---|---|---|
| 6 | Alarm List (countdown header, glowing cards, toggle, swipe delete, + button) | 🟡 brief: `docs/screens/06-alarm-list.md` |
| — | `AlarmRepository` as single source of truth + `AlarmRow` snapshots (fixes 2 crashes) | 🟡 |
| — | Reconcile database ↔ iOS when the list appears (+ race-condition guard `isScheduling`) | 🟡 |
| 8 | Alarm Editor (time wheel, repeat days, label, snooze, sound, missions row) | ⬜ |
| 13 | Sound Picker (categories, preview, volume) | ⬜ |
| 7 | Quick Alarm sheet | ⬜ |
| 30 | Lock screen / Dynamic Island alarm UI (widget extension, polished) | ⬜ |
| — | Re-sync all alarms with AlarmKit on app launch (move reconcile into `AlarmSyncService`, also cancel orphan system alarms) | ⬜ |

## Phase 2 — Ringing flow + first missions
| # | Screen / item | Status |
|---|---|---|
| 14 | Ringing screen (in-app sound, snooze limit) | ⬜ |
| 9 | Mission Picker | ⬜ |
| 10 | Mission Settings (math / typing / shake) | ⬜ |
| 15a–c | Math, Typing, Shake missions | ⬜ |
| 16 | Success screen | ⬜ |
| — | Open ringing screen automatically if an alarm is alerting when the app opens (spike: alarms "ring" forever until stopped) | ⬜ |
| — | Mission lock: while backups are ringing, block switching off / deleting / editing that alarm | ⬜ |
| — | Replace RingingPlaceholder's live `WakeAlarm` with a snapshot (same crash class as Bug 2) | ⬜ |
| — | `WakeRecord` model (SchemaV2 + migration) | ⬜ |

## Phase 3 — Remaining missions
| # | Screen / item | Status |
|---|---|---|
| 15d–f | Memory, Steps, Squat missions | ⬜ |
| 11, 15g | Photo registration + Photo mission | ⬜ |
| 12, 15h | Barcode registration + Barcode mission | ⬜ |
| — | Multiple missions per alarm, mute during mission, Time Pressure | ⬜ |
| 18 | Wake-Up Check | ⬜ |

## Phase 4 — Onboarding, settings, widgets
| # | Screen / item | Status |
|---|---|---|
| 1–4 | Welcome, Survey, Permissions, First alarm | ⬜ |
| 26 | Settings | ⬜ |
| 28 | "Why didn't my alarm ring?" checker | ⬜ |
| 29 | FAQ / contact / legal | ⬜ |
| 31 | Home & lock screen widgets (App Group database) | ⬜ |

## Phase 5 — Morning & records
| # | Screen / item | Status |
|---|---|---|
| 17 | Morning check-in (mood) | ⬜ |
| 23 | Morning panel (WeatherKit, quote, streak) | ⬜ |
| 24 | Records calendar | ⬜ |
| 25 | Stats (Swift Charts) | ⬜ |

## Phase 6 — Sleep sounds
| # | Screen / item | Status |
|---|---|---|
| 19 | Sound library | ⬜ |
| 20 | Player + sleep timer | ⬜ |
| — | Bedtime reminder | ⬜ |

## Phase 7 — Premium & launch
| # | Screen / item | Status |
|---|---|---|
| 5 | Paywall (StoreKit 2) | ⬜ |
| 27 | Premium management | ⬜ |
| — | Database-failure recovery screen (replace `fatalError` in AppDependencies) | ⬜ |
| — | Remove Debug tools, privacy manifest, icon, screenshots, TestFlight, submit | ⬜ |

## Phase 8 — Post-launch
| # | Screen / item | Status |
|---|---|---|
| 21–22 | Sleep tracking + snore detection + report | ⬜ |
| — | Localization (English + Urdu first) | ⬜ |

---

## Changes from the original plan (and why)
- Phase 1 branch is stacked on `phase-0-foundation` (not `main`), because Phase 0 isn't merged yet and
  Phase 1 needs its code. After Phase 0 merges, retarget the Phase 1 PR to `main`.
- Views get value snapshots (`AlarmRow`), never `@Model` objects; `AlarmRepository` owns the live list.
  (Learned from two crashes; see `docs/HOW_IT_WORKS.md` Part 4.)
- Model is named `WakeAlarm`, not `Alarm`: Apple's AlarmKit already has `Alarm`.
- Backup alarm IDs are *calculated* from the alarm ID, not stored, so there's no `backupChainIDs` field. Nothing can go out of sync.
- `ScreenFactory` instead of a "RouteView"; typed route arrays instead of `NavigationPath` (easier to inspect).
- Widget extension moved from Phase 1 to Phase 0: the spike showed alarms have no visible UI on an unlocked phone without it.
