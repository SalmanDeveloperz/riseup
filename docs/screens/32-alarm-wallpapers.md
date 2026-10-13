# Screen #32 Alarm Wallpapers: brief & review guide

**Phase 7+** · on `development` · database **SchemaV3** (new: `WakeAlarm.wallpaperID`)

## What it does
The Ringing screen gets a living background. Different from Alarmy, and on purpose:
- **14 live wallpapers drawn by RiseUp in real time**, in 5 categories:
  Sunrise (Golden Hour, Aurora, Dawn Drift) · Nature (Ocean Waves, Firefly Forest, Rainy Window) ·
  Space (Hyperspace, Nebula, Planet Rise) · Neon Energy (Synthwave, Neon Pulse, Lava Lamp) · Calm (Breathe, Bokeh Lights).
  No video files: they load instantly, stay sharp on every screen and add almost nothing to the download.
- **They wake up with you.** When the alarm rings, the wallpaper starts calm and gets brighter, busier and
  faster over 40 seconds ("energy"). During missions it dims, so the task stands out; on "You're up!" it
  celebrates at full energy.
- **Your own photos**, with a slow cinematic zoom ("Ken Burns"). Added from the photo library, stored as small files.
- **Surprise me**: a different wallpaper every morning (same all day, new tomorrow).
- **Picker** with live animated cards per category, and a full-screen **"Try it"** preview showing the real
  clock on top and the energy rising ("Waking up 40 %", tap it to replay).
- **Per alarm** (editor → Wallpaper) or **for all alarms** (Settings → Alarm wallpaper).

Also in this change: **Developer mode**. In Debug builds the 🐞 menu, Developer section, "Close (debug)"
and "Add sample data" buttons are now hidden until you tap the version number in Settings 7 times.
(App Store builds never contain them.)

## Connection map
```
Editor "Wallpaper" row → AlarmEditorViewModel.chooseWallpaper()
  → AppCoordinator.presentWallpaperPicker(selected:allowsDefault:onPick:) → sheet = .wallpaperPicker
  → ScreenFactory → WallpaperPickerView(WallpaperPickerViewModel(store: WallpaperStore, …))
       card tap → previewing = wallpaper → WallpaperPreviewView (full screen, energy ramp 8 s)
       "Use this wallpaper" → viewModel.use → coordinator.completeWallpaperPicker → onPick
  → draft.wallpaper → Save → WakeAlarm.wallpaperID = "live.synthwave"

Alarm rings → RingingViewModel.start()
  → info.wallpaper = alarm.wallpaperID ?? settings.defaultWallpaper, "Surprise" resolved for today
  → photo? → WallpaperStore.image(for:) (background decode, cached)
RingingView.background → WallpaperView(energy: .ramp(start: ringStartedAt, duration: 40))
  → LiveWallpaperView: TimelineView (60 fps) → Canvas → <Style>Renderer.draw(context, size, time, energy)
```

## Files, in reading order
1. `Models/Wallpaper.swift`: `Wallpaper`, `LiveWallpaper`, `WallpaperCategory`, `WallpaperEnergy` (read the LEARN on `clock`)
2. `Models/SchemaV3.swift` + `RiseUpMigrationPlan.swift`: the database upgrade V2 → V3
3. `Features/Wallpapers/Renderers/WallpaperKit.swift`: how a live wallpaper works (LEARN), then any renderer,
   e.g. `EnergyWallpapers.swift` → `SynthwaveRenderer`
4. `Features/Wallpapers/Views/WallpaperView.swift`: live / photo / scrim
5. `Services/Wallpaper/WallpaperStore.swift`: photo files, fast loading
6. `Features/Wallpapers/ViewModels/WallpaperPickerViewModel.swift` → `Views/WallpaperPickerView.swift` → `WallpaperPreviewView.swift`
7. Editor: `AlarmEditorViewModel` (MARK Wallpaper) · Settings: `SettingsViewModel.chooseDefaultWallpaper`, `versionTapped`
8. Ringing: `RingingViewModel` (MARK Wallpaper) → `RingingView.background`
9. `Coordinator/DeveloperTools.swift` (environment value) and where it's read
10. Tests: `RiseUpTests/WallpaperTests.swift`

## Data
| Reads | Writes |
|---|---|
| `WakeAlarm.wallpaperID`, `AppSettings.defaultWallpaper` | the same (editor Save / Settings) |
| Photo files in Application Support/Wallpapers | adds / deletes those files |

## Design decisions (WHY)
- **Code, not video:** instant, tiny, sharp, and able to react to the alarm. Each wallpaper is one pure
  function of `(time, energy)`: nothing stored between frames, so nothing can leak or drift.
- **Energy never multiplies time** (it would make the animation jump); speed-ups come from
  `WallpaperEnergy.clock`, the integral of the speed (see its LEARN).
- **Gradients instead of blur filters** for glows: same look, a fraction of the GPU work.
- **One category on screen at a time** in the picker; thumbnails run at 24 fps, the Ringing screen at 60.
- **Photos are shrunk once when added** (≤ 1290 px) and decoded off the main thread, then cached.
- **A missing photo never leaves a blank screen**: WallpaperView falls back to Golden Hour.
- **Reduce Motion**: wallpapers show a still frame.
- **A dark halo behind the clock** keeps it readable on bright wallpapers (found on Synthwave's sun).

## Test on the iPhone
- Ring an alarm with each category; the animation stays smooth (no stutter) for minutes.
- Add a big photo from the library: it appears in about a second; ring with it.
- Settings → Accessibility → Motion → Reduce Motion: wallpapers stand still.

## Exercises
1. **TRY:** `RingingViewModel.wallpaperRampSeconds = 20` for a faster wake-up build-up.
2. **TRY:** in `SynthwaveRenderer`, change the grid colour `0xFF4FD8` to cyan `0x3DD6FF`.
3. Make your own wallpaper: add a case to `LiveWallpaper`, a renderer (copy `BokehRenderer`), and a line in
   `LiveWallpaperView.draw`. Then add it to the category in `LiveWallpaper.category`.
