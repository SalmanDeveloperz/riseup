# Phase 0 Spike: AlarmKit on a real iPhone

Goal: prove that AlarmKit supports our design **before** building real screens on top of it.
Run everything on your **iPhone** (not the Simulator), from Xcode, after the widget extension exists.

Open the app → **Settings → Developer → AlarmKit Lab**.

## Already observed in the Simulator (2026-10-06)
| Check | Result |
|---|---|
| Permission popup shows our text from `Config/Info.plist` | ✅ |
| Main alarm + 5 backups scheduled; Lab list updates live | ✅ |
| System picked our custom tone (`spike_beep.caf`) as the alarm sound (seen in system log) | ✅ (verify by ear on device) |
| Ringing alarm visible on an **unlocked** screen | ❌ Nothing appeared, because the app has no widget extension (system log: "Reloading descriptors for 0 extensions"). → Create `RiseUpWidgets` first |

## Experiments to run on the iPhone
For each one, write what happened. Lab log lines can be long-pressed to copy.

### A · Permission
- [ ] Popup appears, Allow → Lab shows `authorized`

### B · Custom sound (each rings ~60 s later; lock the phone)
- [ ] `spike_beep.caf` → plays our beeps? ______
- [ ] `spike_beep` (no extension) → plays our beeps? ______
- [ ] `default` → system sound? ______
- [ ] Silent switch ON: still rings loudly? ______

### C · Mission alarm + backup chain
Run twice: once with **phone locked**, once **unlocked inside another app**.
- [ ] Main alarm rings at the shown minute ______
- [ ] "Start Mission" button visible ______
- [ ] Tap "Start Mission" → RiseUp opens on the Ringing screen ______
- [ ] "Complete mission (test)" → backups disappear from the Lab list ______
- [ ] New alarm, tap **Stop** instead → backup rings at +1 min ______ and keeps going (+2, +3…) ______
- [ ] Repeat with the app **force-quit** (swipe up in app switcher) before it rings ______
- [ ] With "Repeat on today's weekday" ON: after Stop/Complete, is the main alarm still listed (for next week)? ______

### D · Snooze
- [ ] "Snooze" button visible ______
- [ ] Tap Snooze → rings again ~1 min later ______
- [ ] Countdown shown on lock screen / Dynamic Island while snoozing ______

### E · Limit
- [ ] Number reported by "Run limit test": ______

## Decisions after the spike
(Claude fills this in with you once results are in.)
