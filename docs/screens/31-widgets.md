# #31 Home & lock screen widgets: brief & review guide

**Phase 7+** · on `development` · new App Group `group.com.testProject.Alarm` · no database change

## What it does
"Next alarm" in the widget gallery (it wasn't there before: the extension only had the alarm Live Activity).
- **Small:** the next alarm on **its own wallpaper**, day ("TOMORROW"), missions, time, title, live countdown.
- **Medium:** + the next two alarms and **quick naps** (+10 / +20 / +30 min).
- **Large:** + sound and wallpaper names, three more alarms, quick naps.
- **Lock screen:** circle (⏰ 7:00), rectangle (time, day · title, countdown) and one line above the clock.
- **Taps:** an alarm opens it in the editor; a nap opens Quick Alarm preset to that time; empty → new alarm.
- After an alarm rings, the widget **moves to the next one by itself**, even if RiseUp isn't opened.

## Connection map
```
App: RootView (after every sync, and when RiseUp goes to the background)
  → WidgetBridge.update(alarms, settings, wallpaperStore)
       plan(): every ring of every ON alarm in 8 days (wallpaper resolved per ring)
       still(of:): ImageRenderer(WallpaperStill) → wp1-live.kyotoBlossoms.jpg  (once per wallpaper)
       WidgetSnapshot.save() → App Group UserDefaults "widgetSnapshot.v1"
       changed? → WidgetCenter.reloadTimelines(ofKind: "RiseUpNextAlarm")
Widget extension: NextAlarmProvider.getTimeline
       → WidgetSnapshot.load() → entries: now + just after each ring → NextAlarmWidgetView
Tap: Link / widgetURL riseup://alarm/<id> | nap/<min> | new
  → app RootView .onOpenURL → DeepLink(url:) → AppCoordinator.open(_:)
```

## Files, in reading order
1. `Config/Alarm.entitlements` + `Config/RiseUpWidgets.entitlements` (the App Group), `Config/Info.plist` (URL scheme)
2. `Shared/WidgetSnapshot.swift`: what the app and widget share
3. `Services/Widgets/WidgetBridge.swift`: `plan` (pure) → `update` → `still`
4. `RiseUpWidgets/NextAlarmWidget.swift`: read the header "HOW A WIDGET WORKS", then provider → views
5. `Coordinator/DeepLink.swift` → `AppCoordinator.open(_:)` → `RootView` `.onOpenURL`
6. Tests: `RiseUpTests/WidgetTests.swift`

## Design decisions (WHY)
- **A snapshot, not the database:** sharing SwiftData would mean moving the database into the group folder (a risky
  migration) and loading the whole model in a tiny extension. A week of rings as JSON is all a widget needs.
- **Still pictures of the wallpapers:** widgets are drawn once, not 60 times a second. The app freezes each
  wallpaper at a good moment with the same renderer as the Ringing screen.
- **Links, not buttons that act in the background:** a nap needs permission checks and scheduling in the app;
  opening Quick Alarm preset is one tap more but never fails silently.
- **No wallpaper in the alarm's Live Activity:** a too-big picture can make iOS drop a Live Activity, and that
  view is what shows a ringing alarm on an unlocked phone. Not worth the risk.
- **Free Apple Account:** App Groups work with a Personal Team (Xcode registers the group on the first iPhone
  build). If it ever can't, the widget says "Open RiseUp once…" instead of showing wrong data.

## Test on the iPhone
1. Build to the iPhone, open RiseUp once, go Home → long-press → Edit → Add Widget → RiseUp → add all 3 sizes.
2. Lock screen → Customise → add the circle and the rectangle.
3. Change an alarm's wallpaper in RiseUp, go Home: the widget shows the new picture.
4. Tap +20 → Quick Alarm opens at 20 min. Tap the alarm → its editor opens.

## Exercises
1. **TRY:** in `NapButtons`, change `[10, 20, 30]` to `[5, 15, 45]`.
2. **TRY:** `WallpaperStill` energy `0.55` → `1`, bump `wp1` to `wp2` in `WidgetShared`, rebuild: brighter widgets.
3. Show the alarm's sound (`event.soundTitle`, with `music.note`) under the title in `SmallView`.
