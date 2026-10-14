# RiseUp Roadmap & Progress

Status: ⬜ todo · 🟡 built, waiting for Salman's review · ✅ reviewed & done

Screen numbers (#) match the original feature list. Every screen gets a brief in `docs/screens/`.

---

## Phase 0 — Foundation  ·  on `development`
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
| **Widget extension target `RiseUpWidgets`** | 🟡 | Added in Phase 1 (#30) with the `Shared/` folder; see `docs/screens/30-lock-screen-alarm-ui.md` |
| **Unit test target `RiseUpTests`** + shared `Alarm` scheme (⌘U runs the tests) | 🟡 | Added in Phase 3/4: 44 tests (dates, IDs, missions, repositories, sync rules, photo matching, ringing flow, health check, review fixes) |
| Spike experiments A–E on a real iPhone → `docs/SPIKE_RESULTS.md` | ⬜ | |
| Decide final bundle ID (currently `com.testProject.Alarm`) | ⬜ | Must be final before App Groups (Phase 4) / App Store |

## Phase 1 — Alarms core  ·  on `development`
| # | Screen / item | Status |
|---|---|---|
| 6 | Alarm List (countdown header, glowing cards, toggle, swipe delete, + button) | 🟡 brief: `docs/screens/06-alarm-list.md` |
| — | `AlarmRepository` as single source of truth + `AlarmRow` snapshots (fixes 2 crashes) | 🟡 |
| — | Reconcile database ↔ iOS when the list appears (+ race-condition guard `isScheduling`) | 🟡 |
| 8 | Alarm Editor (time wheel, repeat days, label, snooze, sound, missions row) | 🟡 brief: `docs/screens/08-alarm-editor.md` |
| — | Shared `requirePermission()`, `countdownText`, `Weekday.summary`; Preview crash fix (repository keeps container) | 🟡 |
| 13 | Sound Picker (categories, preview) + 8 generated sounds + `AudioService` | 🟡 brief: `docs/screens/13-sound-picker.md` |
| 7 | Quick Alarm sheet (exact `.fixed` time, deletes itself after ringing) | 🟡 brief: `docs/screens/07-quick-alarm.md` |
| 30 | Lock screen / Dynamic Island alarm UI (widget extension) | 🟡 brief: `docs/screens/30-lock-screen-alarm-ui.md` |
| — | `AlarmSyncService`: sync on launch + every foreground; cancels orphan system alarms; re-arms missing backup chains | 🟡 |
| — | `SchemaV2` (+ `fixedFireDate`, `WakeRecord`) with a lightweight migration from V1 (tested: existing alarms kept) | 🟡 |

## Phase 2 — Ringing flow + first missions
| # | Screen / item | Status |
|---|---|---|
| 14 | Ringing screen (in-app sound with volume ramp, snooze limit) | 🟡 brief: `docs/screens/14-16-ringing-flow.md` |
| 9 | Mission Picker | 🟡 brief: `docs/screens/09-10-mission-picker.md` |
| 10 | Mission Settings + "Try it now" practice | 🟡 |
| 15a–c | Math, Typing, Shake missions (quiet while active, alarm returns after 15 s idle) | 🟡 |
| 16 | Success screen (confetti, stats) | 🟡 |
| — | Open ringing screen automatically if an alarm is alerting when the app opens (spike: alarms "ring" forever until stopped) | 🟡 |
| — | Mission lock: while backups are ringing, block switching off / deleting / editing that alarm + "Finish your mission" banner | 🟡 |
| — | Replace RingingPlaceholder's live `WakeAlarm` with a snapshot (same crash class as Bug 2) | 🟡 placeholder removed; `RingInfo` snapshot |
| — | `WakeRecord` model (SchemaV2 + migration), one record per wake-up | 🟡 |

## Phase 3 — Remaining missions
| # | Screen / item | Status |
|---|---|---|
| 15d–f | Memory, Steps, Squat missions | 🟡 brief: `docs/screens/15d-h-phase3-missions.md` |
| 11, 15g | Photo registration + Photo mission (Vision feature prints) | 🟡 ⚠️ tune `VisionPhotoMatcher.matchThreshold` on a real iPhone |
| 12, 15h | Barcode registration + Barcode mission (VisionKit live scanner) | 🟡 |
| — | Safety net: missing sensor/permission → Math; "Can't match?" → hard Math | 🟡 |
| — | Multiple missions per alarm (up to 3, in order) | 🟡 done early in Phase 2 |
| — | Time Pressure (spoken time every minute during missions) | 🟡 brief: `docs/screens/18-wake-up-check-and-time-pressure.md` |
| — | Mute button during mission | ➖ dropped: missions already silence the alarm while you're active (15 s idle → it returns) |
| 18 | Wake-Up Check | 🟡 |

## Phase 4 — Onboarding, settings, widgets
| # | Screen / item | Status |
|---|---|---|
| 1–4 | Welcome, Goal, Permission, First alarm | 🟡 brief: `docs/screens/01-04-onboarding.md` |
| 26 | Settings (Time Pressure, default sound & snooze, help, replay intro) | 🟡 brief: `docs/screens/26-29-settings.md` |
| 28 | "Why didn't my alarm ring?" checker with one-tap fixes | 🟡 |
| 29 | FAQ + Privacy | 🟡 contact & privacy-policy URL still needed (Phase 7) |
| 31 | Home & lock screen widgets | 🟡 built in Phase 7+ (see below) |

## Phase 5 — Morning & records
| # | Screen / item | Status |
|---|---|---|
| 17 | Morning check-in (mood) | 🟡 brief: `docs/screens/17-23-25-morning-records-stats.md` |
| 23 | Morning panel (quote, streak, today, next alarm, week chart) | 🟡 weather moved to Phase 7 (needs the final bundle ID) |
| 24 | Records calendar | 🟡 |
| 25 | Stats (Swift Charts) | 🟡 |

## Phase 6 — Sleep sounds
| # | Screen / item | Status |
|---|---|---|
| 19 | Sound library (10 sounds, mix up to 3, last mix) | 🟡 brief: `docs/screens/19-20-sleep-sounds.md` |
| 20 | Player + sleep timer (background audio, lock-screen controls) | 🟡 needs the iPhone test list in the brief |
| — | Bedtime reminder (daily notification) | 🟡 |

## Phase 7 — Launch readiness (RiseUp is completely free: no paywall, decided 2026-10-13)
| # | Screen / item | Status |
|---|---|---|
| — | Fast camera: own `CameraScreen` + background `CameraSession` (old picker froze on iPhone) | 🟡 test on iPhone |
| — | 11 new alarm sounds (20 in total) | 🟡 listen on iPhone |
| — | Pre-launch code reviews (alarm core + smoothness) and fixes | 🟡 see HOW_IT_WORKS Bugs 27–40 |
| — | Database-failure recovery (no more `fatalError`) | 🟡 |
| — | App icon + in-app logo (`Tools/generate_app_icon.swift`), v3: the Crowing Rooster (chosen by Salman) | 🟡 done 2026-10-14 |
| — | Privacy manifest, export compliance key, dark launch screen | 🟡 |
| — | Release build check (zero warnings, no debug tools inside) | 🟡 |
| — | App Store texts, privacy policy, review notes, screenshot plan | 🟡 `docs/APP_STORE.md`, `docs/PRIVACY_POLICY.md` |
| 32 | Alarm wallpapers: 14 live + own photos + Surprise, energy ramp, picker + "Try it" (SchemaV3) | 🟡 brief: `docs/screens/32-alarm-wallpapers.md` |
| — | Developer mode (debug tools hidden until 7 taps on the version) | 🟡 |
| 33 | Scene Player: wallpaper + its own sound, ⏮ ▶︎ ⏭, ♥ Saved, "Wallpaper only"; Around the World (11 scenes) | 🟡 brief: `docs/screens/33-scene-player.md` |
| — | 17 new alarm sounds (36 in total): Around the world, Nature, Music | 🟡 listen on iPhone |
| 34 | Wake-up guarantee: every alarm re-rings 30 s after Stop / a button press; "Wake up" opens the wallpaper + sound; keep-alive on the Ringing screen; low-volume hint | 🟡 brief: `docs/screens/34-wake-up-guarantee.md` · test on iPhone |
| 31 | Home & lock screen widgets: next alarm on its wallpaper, countdown, naps, 6 sizes (App Group) | 🟡 brief: `docs/screens/31-widgets.md` · add them on the iPhone |
| 23b | Weather on the Morning panel | ⬜ needs the final bundle ID (WeatherKit) |
| — | Final bundle ID, App Store Connect, hosted privacy policy, TestFlight, submit | ⬜ Salman (steps in `docs/APP_STORE.md`) |
| ~~5, 27~~ | ~~Paywall, premium management~~ | ➖ dropped: the app is free |

## Phase 8 — Post-launch
| # | Screen / item | Status |
|---|---|---|
| 21–22 | Sleep tracking + snore detection + report | ⬜ |
| — | Localization (English + Urdu first) | ⬜ |

---

## Changes from the original plan (and why)
- Git: per-phase branches replaced by `main` + `development` (2026-10-07). Phase 0 was merged into `main`
  by mistake and reverted; `development` starts with "Reapply Phase 0" so its PR into `main` carries everything.
- Views get value snapshots (`AlarmRow`), never `@Model` objects; `AlarmRepository` owns the live list.
  (Learned from two crashes; see `docs/HOW_IT_WORKS.md` Part 4.)
- Model is named `WakeAlarm`, not `Alarm`: Apple's AlarmKit already has `Alarm`.
- Backup alarm IDs are *calculated* from the alarm ID, not stored, so there's no `backupChainIDs` field. Nothing can go out of sync.
- `ScreenFactory` instead of a "RouteView"; typed route arrays instead of `NavigationPath` (easier to inspect).
- Widget extension moved from Phase 1 to Phase 0: the spike showed alarms have no visible UI on an unlocked phone without it.
  It was finally added in Phase 1 by editing `project.pbxproj` (build-checked), not with Xcode's wizard.
- `Theme.swift` and `RiseUpAlarmMetadata.swift` moved to `Shared/` (compiled into the app AND the widget extension).
- Alarm sounds are generated by our own script (`Tools/generate_sounds.py`): no licences to worry about (`docs/ASSETS.md`).
- Snooze for mission alarms is not offered at all (a mission alarm can't be skipped); plain alarms snooze inside the app
  with a limit, using a `.fixed` one-off system alarm (`AlarmKitScheduler.scheduleSnooze`).
- Quick alarms use a new stored field `fixedFireDate` (SchemaV2) so "in 1 minute" rings at the exact second.
- Phase 3: no schema change was needed. Photo/Barcode registrations use `MissionConfig.textPayload/dataPayload`
  (planned in SchemaV1), and the Wake-Up Check uses `WakeAlarm.wakeUpCheckMinutes` (also already there).
- The "mute button during missions" was dropped: the alarm is already silent while you work, and comes back after
  15 s idle (longer for walking missions).
- Vision's photo fingerprints don't work in the Simulator; the Simulator uses a simple pixel matcher (`PixelPhotoMatcher`).
- Home/lock-screen widgets (31) wait for the final bundle ID, because they need an App Group.
- Weather on the Morning panel moved to Phase 7 for the same reason (WeatherKit is switched on per bundle ID).
- RiseUp is **completely free** (2026-10-13): the paywall (#5) and premium management (#27) were dropped;
  Phase 7 became "launch readiness".
- Alarm wallpapers (#32, 2026-10-13) are drawn live in code instead of videos (instant, tiny, react to the
  alarm). First real schema upgrade after V2: SchemaV3 adds `WakeAlarm.wallpaperID`.
- The "Try it" preview became the Scene Player (#33): every wallpaper has its own sound, and choosing one can
  set the alarm's sound too (`WallpaperChoice`). Bookmarks are a preference (`AppSettings`), not database data.
- Widgets (#31, 2026-10-13) didn't wait for the final bundle ID after all: an App Group ID is any `group.…` name
  and doesn't change with the bundle ID. They share a JSON snapshot + wallpaper pictures, not the database.
- Backup chains (#34, 2026-10-13) now protect EVERY alarm (Settings switch, on by default) and start 30 s after a
  ring, because iOS lets the side/volume buttons silence any app's alarm (found on Salman's iPhone).
- The camera no longer uses Apple's `UIImagePickerController` (it froze the app on a real iPhone); RiseUp has its own.
- Sleep sounds are generated by our own script too (`Tools/generate_sleep_sounds.py`), not downloaded: no licences.
- The sleep mixer lives in a long-lived service (`SleepSoundPlayer`), not a ViewModel, so music survives leaving the screen.
