# Screen #30 · Lock Screen & Dynamic Island alarm UI: brief & review guide

**Phase 1** · on `development` · new target **RiseUpWidgets** (widget extension)

## What it does
When a RiseUp alarm rings (or snoozes with the system countdown), iOS shows it as a **Live Activity**.
This screen is how it looks:
- **Dynamic Island, compact:** pink alarm icon on the left, ring time on the right (e.g. "5:15 PM")
- **Dynamic Island, expanded** (long-press): gradient badge, alarm title, "Time to rise and shine", big gradient time
- **Lock screen banner:** the same, as one row
- **Backups** show a ⚡ and "Open RiseUp and finish your mission". **Countdowns** show a live timer. **Paused** shows the time left.

Tapping it opens RiseUp, and the Ringing screen appears by itself (Screens 14–16).

## What changed in the project (read this first!)
| Change | Why |
|---|---|
| New target **RiseUpWidgets** (`RiseUpWidgets.appex`, bundle ID `com.testProject.Alarm.RiseUpWidgets`) | A widget extension is a 2nd tiny program inside the app; iOS runs it to draw Live Activities |
| New folder **`RiseUpWidgets/`**: the extension's code | Synchronized folder: files there join the *extension* target automatically |
| New folder **`Shared/`**: in **both** targets | The app and the extension must use the very same `RiseUpAlarmMetadata` type and colours |
| `RiseUpAlarmMetadata.swift` moved `Alarm/Services/AlarmKit/` → `Shared/` | Shared type (see its WHY) |
| `Theme.swift` moved `Alarm/DesignSystem/` → `Shared/DesignSystem/` | The lock screen uses the same neon colours |
| `Config/RiseUpWidgets-Info.plist` | Tells iOS "this is a WidgetKit extension" (`NSExtension`) |
| App: `NSSupportsLiveActivities = YES` | Allows the app's alarms to appear as Live Activities |
| App target: "Embed Foundation Extensions" build phase | Copies the `.appex` into `RiseUp.app/PlugIns/` |

In Xcode you'll now see two schemes, **Alarm** and **RiseUpWidgets**. Keep running **Alarm**. It builds the extension too.

## Connection map
```
AlarmKitScheduler.makeAttributes(...)        ← in the APP
   AlarmAttributes<RiseUpAlarmMetadata>(presentation, metadata, tintColor)
   → AlarmManager.shared.schedule(...)       → iOS stores the attributes
                                               (the app can now be closed)
alarm time → iOS starts a Live Activity → launches the EXTENSION
   RiseUpWidgetsBundle (@main)
     └─ AlarmLiveActivity: ActivityConfiguration(for: AlarmAttributes<RiseUpAlarmMetadata>.self)
          ├─ AlarmActivityInfo(attributes:, state:)   ← "tiny ViewModel": title / icon / timing
          ├─ AlarmLockScreenView                      ← lock screen
          └─ DynamicIsland { expanded | compact | minimal }
user taps it → RiseUp opens → RootView sync → Ringing screen
```

## Files, in reading order
1. `Shared/RiseUpAlarmMetadata.swift`: WHY a shared folder
2. `RiseUpWidgets/RiseUpWidgetsBundle.swift`: the extension's `@main`
3. `RiseUpWidgets/AlarmLiveActivity.swift`: `AlarmActivityInfo` first, then the views, then the `#Preview`
4. `Config/RiseUpWidgets-Info.plist`
5. `Services/AlarmKit/AlarmKitScheduler.swift` → `makeAttributes`: where title, tint and metadata come from

## Data
| Reads | Writes |
|---|---|
| `AlarmAttributes` (title, tint, `RiseUpAlarmMetadata`) + `AlarmPresentationState` (alert / countdown / paused), both from iOS | Nothing. Extensions can't open our database (that needs an App Group, Phase 4). |

## Design decisions (WHY)
- **No buttons in our views:** while the alarm rings, iOS draws its own Stop / "Start Mission" buttons from
  `AlarmPresentation.Alert`. Our job is the look around them.
- **`Text(date, style: .timer)`** for countdowns: the extension isn't running every second. iOS updates this text by itself.
- **The type must match exactly:** `ActivityConfiguration(for: AlarmAttributes<RiseUpAlarmMetadata>.self)`.
  A different metadata type means iOS can't find a matching UI, and the alarm shows no UI on an unlocked phone.
- **The target was added by editing `project.pbxproj`** (instead of Xcode's New Target wizard) so the change could be
  build-checked and reviewed as one diff. Open the project in Xcode and look at *Targets → RiseUpWidgets → General* to see it.

## How to try it
- **Xcode canvas:** open `AlarmLiveActivity.swift` → the preview shows ringing, countdown and paused side by side.
- **Simulator:** ⚡ → 1 min → go to the Home Screen (⇧⌘H) → wait. The Dynamic Island shows the alarm; long-press it.
- **iPhone (real test):** same with the phone unlocked, then again with it locked.

## Exercises
1. **TRY:** change the subtitle "Time to rise and shine" in `AlarmActivityInfo.subtitle`. Run it and look at the island.
2. Change `compactLeading` to show `AlarmIconBadge(info: info, size: 24)` instead of the plain icon. Better or worse?
3. Why can't the widget show "Math · 3 problems"? What would the app have to put into `RiseUpAlarmMetadata` to make it
   possible? (Remember: changing it changes what's stored with *already scheduled* alarms.)
