# RiseUp: the mission alarm clock

An iPhone alarm that won't let you sleep through it: to stop it you complete a **mission** (maths, typing,
memory, shake, steps, squats, a photo of a registered place, or a barcode scan). Real system alarms via
**AlarmKit**, live animated wallpapers with their own sounds, home & lock screen widgets, sleep sounds,
a morning check-in and stats. Free, no account, no server: everything stays on the phone.

- **Platform:** iPhone, iOS 26+, portrait, dark UI
- **Stack:** Swift 6 · SwiftUI · SwiftData · AlarmKit · WidgetKit · MVVM + Coordinator · no third-party libraries
- **Logo:** the Crowing Rooster, nature's alarm clock

## Build & run
1. Open `Alarm.xcodeproj` in Xcode 26, scheme **Alarm**.
2. Run on an iPhone with iOS 26 (alarms need a real device; the Simulator is for UI).
   - First iPhone build: Signing & Capabilities → choose your team. Xcode registers the App Group for the widgets.
3. Tests: ⌘U, or `xcodebuild test -scheme Alarm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
4. Release check: `xcodebuild -scheme Alarm -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

## Project map
| Folder | What's inside |
|---|---|
| `Alarm/` | the app: `App/` (start-up, dependencies), `Coordinator/` (navigation), `Features/` (one folder per screen: Views + ViewModels), `Models/` (SwiftData schemas), `Repositories/`, `Services/` (AlarmKit, audio, camera, motion, widgets…), `DesignSystem/`, `Resources/` (sounds) |
| `RiseUpWidgets/` | widget extension: the alarm's Live Activity + the Next alarm widget |
| `Shared/` | code compiled into BOTH the app and the widget (Theme, alarm metadata, widget snapshot) |
| `RiseUpTests/` | unit tests (Swift Testing) |
| `Tools/` | scripts run on the Mac: `generate_sounds.py`, `generate_sleep_sounds.py`, `generate_app_icon.swift` |
| `Config/` | Info.plist extras and entitlements (App Group) |
| `docs/` | everything to understand the project (below) |

## Documentation, in reading order
1. **`docs/TALKING_POINTS.md`**: how to explain RiseUp to anyone: how alarms ring, notifications, wallpapers,
   sounds, frameworks, iOS versions, privacy. **Start here.**
2. `CLAUDE.md`: the project rules (architecture, comment style, git workflow)
3. `docs/ROADMAP.md`: what's done, what's next
4. `docs/ARCHITECTURE.md`: layers, start-up, alarm lifecycle, data map, frameworks
5. `docs/HOW_IT_WORKS.md`: traces through the code, and every real bug with the rule it taught
6. `docs/screens/NN-*.md`: one brief per screen, with a connection map and exercises
7. `docs/LEARNING_GUIDE.md`: Swift/SwiftUI concepts, each linked to the file that uses it
8. `docs/ASSETS.md` (sounds, icons, licences) · `docs/APP_STORE.md` (launch steps) · `docs/PRIVACY_POLICY.md`
